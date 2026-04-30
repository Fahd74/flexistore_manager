#include "installments_functions.h"
#include "core/db_connection_pool.h"
#include "core/json_builder.h"

#include <cppconn/prepared_statement.h>
#include <cppconn/resultset.h>
#include <cppconn/statement.h>
#include <cppconn/exception.h>
#include <iostream>
#include <cmath>

using namespace flexistore;

namespace {
struct ConnGuard {
    DBConnectionPool& p;
    std::unique_ptr<sql::Connection> c;
    ~ConnGuard() { if (c) p.releaseConnection(std::move(c)); }
};
} // namespace

extern "C" {

// ── get_all_installments ──────────────────────────────────────────────────────
FLEXISTORE_EXPORT const char* get_all_installments() {
    try {
        auto& pool = DBConnectionPool::getInstance();
        auto  conn = pool.getConnection();
        if (!conn) return allocate_ffi_string("[]");
        ConnGuard g{pool, std::move(conn)};

        // JOIN with clients to get name + phone in one query
        std::unique_ptr<sql::Statement> stmt(g.c->createStatement());
        std::unique_ptr<sql::ResultSet> rs(stmt->executeQuery(
            "SELECT i.id, i.client_id, c.name AS client_name, c.phone AS client_phone, "
            "       i.invoice_id, i.total_amount, i.remaining_amount, "
            "       i.months, i.monthly_installment, i.status, i.created_at "
            "FROM installments i "
            "JOIN clients c ON c.id = i.client_id "
            "ORDER BY i.created_at DESC"
        ));

        std::string json = JsonBuilder::result_set_to_json(rs.get());
        return allocate_ffi_string(json);

    } catch (const sql::SQLException& e) {
        std::cerr << "[Installments] SQLException in get_all_installments: " << e.what() << std::endl;
        return allocate_ffi_string("[]");
    } catch (...) {
        return allocate_ffi_string("[]");
    }
}

// ── create_installment_plan ───────────────────────────────────────────────────
FLEXISTORE_EXPORT int create_installment_plan(int client_id, int invoice_id,
                                               double total_amount, int months) {
    if (months <= 0)         return FFI_ERROR_INST_INVALID_MONTHS;
    if (total_amount <= 0.0) return FFI_ERROR_INST_INVALID_AMOUNT;

    double monthly = total_amount / static_cast<double>(months);

    try {
        auto& pool = DBConnectionPool::getInstance();
        auto  conn = pool.getConnection();
        if (!conn) return FFI_ERROR_DB_CONNECTION;
        ConnGuard g{pool, std::move(conn)};

        std::unique_ptr<sql::PreparedStatement> pstmt(g.c->prepareStatement(
            "INSERT INTO installments "
            "(client_id, invoice_id, total_amount, remaining_amount, months, monthly_installment) "
            "VALUES (?, ?, ?, ?, ?, ?)"
        ));
        pstmt->setInt(1, client_id);
        pstmt->setInt(2, invoice_id);
        pstmt->setDouble(3, total_amount);
        pstmt->setDouble(4, total_amount); // remaining starts at full amount
        pstmt->setInt(5, months);
        pstmt->setDouble(6, monthly);
        pstmt->executeUpdate();

        // Update client total_debt
        {
            std::unique_ptr<sql::PreparedStatement> upd(g.c->prepareStatement(
                "UPDATE clients SET total_debt = total_debt + ? WHERE id = ?"
            ));
            upd->setDouble(1, total_amount);
            upd->setInt(2, client_id);
            upd->executeUpdate();
        }

        return FFI_SUCCESS;

    } catch (const sql::SQLException& e) {
        std::cerr << "[Installments] SQLException in create_installment_plan: " << e.what() << std::endl;
        return FFI_ERROR_DB_QUERY;
    } catch (...) {
        return FFI_ERROR_UNKNOWN;
    }
}

// ── record_installment_payment ────────────────────────────────────────────────
FLEXISTORE_EXPORT int record_installment_payment(int installment_id,
                                                  int user_id,
                                                  double amount) {
    if (amount <= 0.0) return FFI_ERROR_INST_INVALID_AMOUNT;

    try {
        auto& pool = DBConnectionPool::getInstance();
        auto  conn = pool.getConnection();
        if (!conn) return FFI_ERROR_DB_CONNECTION;
        ConnGuard g{pool, std::move(conn)};

        g.c->setAutoCommit(false);
        try {
            // 1. Fetch current plan
            int    client_id      = 0;
            double remaining      = 0.0;
            std::string status;
            {
                std::unique_ptr<sql::PreparedStatement> sel(g.c->prepareStatement(
                    "SELECT client_id, remaining_amount, status FROM installments WHERE id = ?"
                ));
                sel->setInt(1, installment_id);
                std::unique_ptr<sql::ResultSet> rs(sel->executeQuery());
                if (!rs->next()) {
                    g.c->rollback();
                    return FFI_ERROR_NOT_FOUND;
                }
                client_id = rs->getInt("client_id");
                remaining = rs->getDouble("remaining_amount");
                status    = rs->getString("status");
            }

            if (status == "completed") {
                g.c->rollback();
                return FFI_ERROR_INST_PLAN_CLOSED;
            }
            if (amount > remaining + 0.001) { // tolerance for floating point
                g.c->rollback();
                return FFI_ERROR_INST_OVERPAYMENT;
            }

            double new_remaining = std::max(0.0, remaining - amount);
            std::string new_status = (new_remaining <= 0.001) ? "completed" : "active";

            // 2. Insert payment record
            {
                std::unique_ptr<sql::PreparedStatement> ins(g.c->prepareStatement(
                    "INSERT INTO installment_payments (installment_id, user_id, amount_paid) "
                    "VALUES (?, ?, ?)"
                ));
                ins->setInt(1, installment_id);
                ins->setInt(2, user_id);
                ins->setDouble(3, amount);
                ins->executeUpdate();
            }

            // 3. Update installment remaining + status
            {
                std::unique_ptr<sql::PreparedStatement> upd(g.c->prepareStatement(
                    "UPDATE installments SET remaining_amount = ?, status = ? WHERE id = ?"
                ));
                upd->setDouble(1, new_remaining);
                upd->setString(2, new_status);
                upd->setInt(3, installment_id);
                upd->executeUpdate();
            }

            // 4. Update client total_debt
            {
                std::unique_ptr<sql::PreparedStatement> upd(g.c->prepareStatement(
                    "UPDATE clients SET total_debt = GREATEST(0, total_debt - ?) WHERE id = ?"
                ));
                upd->setDouble(1, amount);
                upd->setInt(2, client_id);
                upd->executeUpdate();
            }

            g.c->commit();
            g.c->setAutoCommit(true);
            return FFI_SUCCESS;

        } catch (...) {
            try { g.c->rollback(); } catch (...) {}
            g.c->setAutoCommit(true);
            throw;
        }

    } catch (const sql::SQLException& e) {
        std::cerr << "[Installments] SQLException in record_installment_payment: " << e.what() << std::endl;
        return FFI_ERROR_DB_QUERY;
    } catch (...) {
        return FFI_ERROR_UNKNOWN;
    }
}

} // extern "C"
