/*******************************************************************************
 * returns_functions.cpp — FlexiStore Manager (Team 6: Returns)
 *
 * Implementation strategy:
 *   - process_return() composes existing primitives:
 *       1. Reads invoice (to know payment_type, client_id, amounts)
 *       2. Begins our own transaction
 *       3. Calls pos_process_return() to create the return invoice + restock
 *       4. If installment-type: reduces clients.total_debt and installments.remaining_amount
 *       5. Inserts an audit row with the reason (transaction_logs)
 *       6. Commits
 *
 *   - Query functions read directly from `invoices` where payment_type='return'.
 *     A return invoice has:
 *       - payment_type = 'return'
 *       - return_of_invoice_id = original invoice's id
 *       - total_amount = NEGATIVE (e.g. -50.00 for $50 refund)
 *       - net_amount   = NEGATIVE
 *     So refund_amount in JSON = ABS(total_amount).
 *
 *   - The "reason" field is stored in transaction_logs.action_type for now
 *     (no dedicated returns table to keep schema changes minimal).
 ******************************************************************************/

#include "returns_functions.h"
#include "../pos/pos_functions.h"
#include "../pos/pos_json_parser.h"
#include "../pos/invoice_queries.h"
#include "../clients/debt_manager.h"
#include "../core/db_connection_pool.h"
#include "../core/json_builder.h"
#include "../audit/audit_logger.h"

#include <mysql/jdbc.h>
#include <memory>
#include <string>
#include <iostream>
#include <cmath>
#include <cstring>

using namespace std;
using namespace flexistore;
using namespace flexistore::data;
using namespace flexistore::pos;

namespace {

// RAII guard — same pattern as the rest of the codebase
struct ConnGuard {
    DBConnectionPool& p;
    unique_ptr<sql::Connection> c;
    ~ConnGuard() { if (c) p.releaseConnection(std::move(c)); }
};

/// Helper: SQL-escape a string for safe LIKE clauses.
/// We use prepared statements normally, but for the search function the
/// query is interpolated into '%query%' so we sanitize quotes.
string escape_like(const string& s) {
    string out;
    out.reserve(s.size());
    for (char c : s) {
        if (c == '\\' || c == '%' || c == '_' || c == '\'') out += '\\';
        out += c;
    }
    return out;
}

/// Helper: build standard return-row JSON output.
/// Used by get_all_returns and search_returns.
void build_returns_array(sql::ResultSet* rs, JsonBuilder& json) {
    json.start_array();
    while (rs->next()) {
        json.start_object();
        json.add_int("id", rs->getInt("id"));

        // Original invoice id (return_of_invoice_id) — may be NULL on legacy rows
        if (rs->isNull("return_of_invoice_id")) {
            json.add_int("invoice_id", 0);
        } else {
            json.add_int("invoice_id", rs->getInt("return_of_invoice_id"));
        }

        if (rs->isNull("client_id")) {
            json.add_int("client_id", 0);
        } else {
            json.add_int("client_id", rs->getInt("client_id"));
        }
        json.add_string("client_name", rs->getString("client_name"));

        // total_amount is stored NEGATIVE for returns; show positive refund
        double total = rs->getDouble("total_amount");
        json.add_double("refund_amount", std::abs(total));

        json.add_string("reason", rs->getString("reason"));
        json.add_string("processed_by", rs->getString("processed_by"));
        json.add_string("created_at", rs->getString("created_at"));

        json.end_object();
    }
    json.end_array();
}

/// Standard SELECT for return rows joined with client name, cashier name,
/// and a derived "reason" pulled from the closest transaction_logs entry.
/// Filters can be appended by the caller.
const string BASE_RETURN_SELECT =
    "SELECT "
    "  ri.id, "
    "  ri.return_of_invoice_id, "
    "  ri.client_id, "
    "  COALESCE(c.name, 'Walk-in') AS client_name, "
    "  CAST(ri.total_amount AS CHAR) AS total_amount, "
    "  COALESCE(u.name, 'System') AS processed_by, "
    "  CAST(ri.created_at AS CHAR) AS created_at, "
    "  COALESCE(("
    "    SELECT tl.action_type FROM transaction_logs tl "
    "    WHERE tl.action_type LIKE CONCAT('RETURN_%') "
    "      AND tl.user_id = ri.user_id "
    "      AND ABS(tl.amount - ABS(ri.total_amount)) < 0.01 "
    "      AND tl.created_at BETWEEN ri.created_at - INTERVAL 5 SECOND "
    "                            AND ri.created_at + INTERVAL 5 SECOND "
    "    ORDER BY tl.created_at DESC LIMIT 1"
    "  ), '') AS reason "
    "FROM invoices ri "
    "LEFT JOIN clients c ON ri.client_id = c.id "
    "LEFT JOIN users u ON ri.user_id = u.id "
    "WHERE ri.payment_type = 'return' ";

} // anonymous namespace

extern "C" {

// ═════════════════════════════════════════════════════════════════════════════
// get_invoice_for_return
// ═════════════════════════════════════════════════════════════════════════════

FLEXISTORE_EXPORT const char* get_invoice_for_return(int user_id, int invoice_id) {
    (void)user_id; // currently unused; reserved for permission checks
    if (invoice_id <= 0) {
        return allocate_ffi_string("{}");
    }

    auto& pool = DBConnectionPool::getInstance();
    ConnGuard guard{pool, pool.getConnection()};
    if (!guard.c) {
        return allocate_ffi_string("{\"error\":\"DB connection failed\"}");
    }
    sql::Connection* conn = guard.c.get();

    try {
        // 1. Verify invoice exists, is not itself a return, and hasn't been returned.
        unique_ptr<sql::PreparedStatement> check(conn->prepareStatement(
            "SELECT "
            "  i.id, i.client_id, i.user_id, "
            "  CAST(i.total_amount AS CHAR) AS total_amount, "
            "  i.payment_type, "
            "  CAST(i.created_at AS CHAR) AS created_at, "
            "  COALESCE(c.name, 'Walk-in') AS client_name "
            "FROM invoices i "
            "LEFT JOIN clients c ON i.client_id = c.id "
            "WHERE i.id = ?"
        ));
        check->setInt(1, invoice_id);
        unique_ptr<sql::ResultSet> rs(check->executeQuery());

        if (!rs->next()) {
            return allocate_ffi_string("{}");  // not found
        }

        string payment_type = rs->getString("payment_type");
        if (payment_type == "return") {
            return allocate_ffi_string("{}");  // it's a return invoice itself
        }

        // Block if there's already a return linked to this invoice
        unique_ptr<sql::PreparedStatement> ret_check(conn->prepareStatement(
            "SELECT id FROM invoices "
            "WHERE payment_type = 'return' AND return_of_invoice_id = ? LIMIT 1"
        ));
        ret_check->setInt(1, invoice_id);
        unique_ptr<sql::ResultSet> ret_rs(ret_check->executeQuery());
        if (ret_rs->next()) {
            return allocate_ffi_string("{}");  // already returned
        }

        // 2. Build the JSON response
        JsonBuilder json;
        json.start_object();
        json.add_int("id", rs->getInt("id"));

        if (rs->isNull("client_id")) {
            json.add_int("client_id", 0);
        } else {
            json.add_int("client_id", rs->getInt("client_id"));
        }
        json.add_string("client_name", rs->getString("client_name"));

        // total_amount via CAST(... AS CHAR) to dodge MySQL Connector DECIMAL bug
        string total_str = rs->getString("total_amount");
        try {
            json.add_double("total_amount", std::stod(total_str));
        } catch (...) {
            json.add_double("total_amount", 0.0);
        }

        // Map our schema's payment_type to the Dart-side expected payment_method
        json.add_string("payment_method", payment_type);  // "cash" or "installment"
        json.add_string("payment_type", payment_type);    // also expose original name
        json.add_string("created_at", rs->getString("created_at"));

        // 3. Items
        unique_ptr<sql::PreparedStatement> items_stmt(conn->prepareStatement(
            "SELECT "
            "  ii.product_id, "
            "  ii.quantity, "
            "  CAST(ii.unit_price AS CHAR) AS unit_price, "
            "  p.name AS product_name, "
            "  p.barcode AS barcode "
            "FROM invoice_items ii "
            "INNER JOIN products p ON ii.product_id = p.id "
            "WHERE ii.invoice_id = ? "
            "ORDER BY ii.id ASC"
        ));
        items_stmt->setInt(1, invoice_id);
        unique_ptr<sql::ResultSet> items_rs(items_stmt->executeQuery());

        json.start_array("items");
        while (items_rs->next()) {
            json.start_object();
            json.add_int("product_id", items_rs->getInt("product_id"));
            json.add_string("product_name", items_rs->getString("product_name"));
            json.add_string("barcode", items_rs->getString("barcode"));
            json.add_int("quantity_sold", items_rs->getInt("quantity"));
            json.add_int("quantity_returned", 0); // whole-invoice return model
            try {
                json.add_double("unit_price", std::stod(items_rs->getString("unit_price")));
            } catch (...) {
                json.add_double("unit_price", 0.0);
            }
            json.end_object();
        }
        json.end_array();
        json.end_object();

        return allocate_ffi_string(json.build());

    } catch (sql::SQLException& e) {
        cerr << "[Returns] SQL error in get_invoice_for_return: " << e.what() << endl;
        return allocate_ffi_string("{\"error\":\"DB query failed\"}");
    } catch (exception& e) {
        cerr << "[Returns] Exception in get_invoice_for_return: " << e.what() << endl;
        return allocate_ffi_string("{\"error\":\"Unexpected error\"}");
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// process_return
// ═════════════════════════════════════════════════════════════════════════════

FLEXISTORE_EXPORT int process_return(
    int user_id,
    int invoice_id,
    const char* items_json,
    const char* reason
) {
    if (invoice_id <= 0) return FFI_ERROR_INVALID_INPUT;

    auto& pool = DBConnectionPool::getInstance();

    // ── Pre-flight: read invoice info (client_id + payment_type + refund total) ──
    // We do this on a separate connection BEFORE calling pos_process_return,
    // because pos_process_return manages its own connection internally.
    int client_id = 0;
    string payment_type;
    double refund_amount = 0.0;
    {
        ConnGuard pre{pool, pool.getConnection()};
        if (!pre.c) return FFI_ERROR_DB_CONNECTION;

        try {
            // Get invoice header
            unique_ptr<sql::PreparedStatement> hdr(pre.c->prepareStatement(
                "SELECT "
                "  client_id, "
                "  payment_type, "
                "  CAST(total_amount AS CHAR) AS total_amount "
                "FROM invoices WHERE id = ?"
            ));
            hdr->setInt(1, invoice_id);
            unique_ptr<sql::ResultSet> hdr_rs(hdr->executeQuery());
            if (!hdr_rs->next()) return FFI_ERROR_RET_INVOICE_NOT_FOUND;

            client_id = hdr_rs->isNull("client_id") ? 0 : hdr_rs->getInt("client_id");
            payment_type = hdr_rs->getString("payment_type");

            // Calculate refund amount.
            // If items_json specifies partial items, use those; otherwise use full invoice total.
            if (items_json && strlen(items_json) > 2) {
                auto requested = parse_items_json(items_json);
                for (auto& it : requested) {
                    refund_amount += it.unit_price * it.quantity;
                }
                if (refund_amount <= 0.0) {
                    // Fallback: compute from invoice_items
                    unique_ptr<sql::PreparedStatement> total_stmt(pre.c->prepareStatement(
                        "SELECT CAST(SUM(quantity * unit_price) AS CHAR) AS s "
                        "FROM invoice_items WHERE invoice_id = ?"
                    ));
                    total_stmt->setInt(1, invoice_id);
                    unique_ptr<sql::ResultSet> ts(total_stmt->executeQuery());
                    if (ts->next() && !ts->isNull("s")) {
                        try { refund_amount = std::stod(ts->getString("s")); } catch (...) {}
                    }
                }
            } else {
                // Full-invoice return: refund = invoice total
                try {
                    refund_amount = std::stod(hdr_rs->getString("total_amount"));
                } catch (...) {}
            }
        } catch (sql::SQLException& e) {
            cerr << "[Returns] Pre-flight error: " << e.what() << endl;
            return FFI_ERROR_DB_QUERY;
        }
    }

    // ── Step 1: delegate to POS team's existing return logic ──────────────
    // It handles: creating the return invoice, restocking, audit, transaction wrapping.
    int return_invoice_id = pos_process_return(user_id, invoice_id, items_json);
    if (return_invoice_id <= 0) {
        return return_invoice_id;  // already a negative error code
    }

    // ── Step 2: For installment invoices, reduce debt + installment plan ──
    if (payment_type == "installment" && client_id > 0 && refund_amount > 0.0) {
        ConnGuard post{pool, pool.getConnection()};
        if (!post.c) {
            // Refund processed but debt not adjusted. Log loudly.
            cerr << "[Returns] WARNING: refund processed but DB connection lost "
                 << "before debt update. Manual reconciliation needed for invoice "
                 << invoice_id << endl;
            return FFI_ERROR_DB_CONNECTION;
        }

        sql::Connection* conn = post.c.get();
        try {
            conn->setAutoCommit(false);

            // 2a. Reduce client's total_debt (debt_manager handles bounds + locking)
            if (!update_client_debt(conn, client_id, -refund_amount)) {
                conn->rollback();
                conn->setAutoCommit(true);
                cerr << "[Returns] WARNING: debt update failed for client " << client_id << endl;
                // Continue — refund itself succeeded. UI sees success.
            }

            // 2b. Reduce installments.remaining_amount for the active plan
            unique_ptr<sql::PreparedStatement> inst_stmt(conn->prepareStatement(
                "SELECT id, "
                "       CAST(remaining_amount AS CHAR) AS remaining_amount, "
                "       CAST(total_amount AS CHAR) AS total_amount "
                "FROM installments "
                "WHERE invoice_id = ? AND status = 'active' "
                "FOR UPDATE"
            ));
            inst_stmt->setInt(1, invoice_id);
            unique_ptr<sql::ResultSet> inst_rs(inst_stmt->executeQuery());

            if (inst_rs->next()) {
                int inst_id = inst_rs->getInt("id");
                double remaining = 0.0;
                try { remaining = std::stod(inst_rs->getString("remaining_amount")); } catch (...) {}

                double new_remaining = remaining - refund_amount;
                if (new_remaining < 0.01 && new_remaining > -0.01) new_remaining = 0.0;

                if (new_remaining <= 0.0) {
                    // Cancel the plan — fully returned
                    unique_ptr<sql::PreparedStatement> cancel(conn->prepareStatement(
                        "UPDATE installments SET remaining_amount = 0, status = 'cancelled' WHERE id = ?"
                    ));
                    cancel->setInt(1, inst_id);
                    cancel->executeUpdate();
                } else {
                    unique_ptr<sql::PreparedStatement> reduce(conn->prepareStatement(
                        "UPDATE installments SET remaining_amount = ? WHERE id = ?"
                    ));
                    reduce->setDouble(1, new_remaining);
                    reduce->setInt(2, inst_id);
                    reduce->executeUpdate();
                }
            }

            conn->commit();
            conn->setAutoCommit(true);
        } catch (sql::SQLException& e) {
            cerr << "[Returns] SQL error during installment adjustment: " << e.what() << endl;
            try { conn->rollback(); conn->setAutoCommit(true); } catch (...) {}
            // Don't fail the whole return — the refund itself is already committed.
        } catch (exception& e) {
            cerr << "[Returns] Exception during installment adjustment: " << e.what() << endl;
            try { conn->rollback(); conn->setAutoCommit(true); } catch (...) {}
        }
    }

    // ── Step 3: Audit log with reason ────────────────────────────────────
    // We use the action_type field to encode the reason so the history query
    // can pull it back. Format: "RETURN_<reason>"
    string action = "RETURN_";
    if (reason && strlen(reason) > 0) {
        // sanitize: trim, clamp length, replace control chars
        string r(reason);
        if (r.size() > 200) r = r.substr(0, 200);
        for (auto& c : r) {
            if (c == '\n' || c == '\r' || c == '\t') c = ' ';
        }
        action += r;
    } else {
        action += "No reason provided";
    }
    log_transaction(user_id, action.c_str(), refund_amount);

    return FFI_SUCCESS;
}

// ═════════════════════════════════════════════════════════════════════════════
// get_all_returns
// ═════════════════════════════════════════════════════════════════════════════

FLEXISTORE_EXPORT const char* get_all_returns(int user_id) {
    (void)user_id;

    auto& pool = DBConnectionPool::getInstance();
    ConnGuard guard{pool, pool.getConnection()};
    if (!guard.c) return allocate_ffi_string("[]");

    try {
        string sql = BASE_RETURN_SELECT + " ORDER BY ri.created_at DESC LIMIT 200";
        unique_ptr<sql::PreparedStatement> stmt(guard.c->prepareStatement(sql));
        unique_ptr<sql::ResultSet> rs(stmt->executeQuery());

        JsonBuilder json;
        build_returns_array(rs.get(), json);
        return allocate_ffi_string(json.build());

    } catch (sql::SQLException& e) {
        cerr << "[Returns] SQL error in get_all_returns: " << e.what() << endl;
        return allocate_ffi_string("[]");
    } catch (exception& e) {
        cerr << "[Returns] Exception in get_all_returns: " << e.what() << endl;
        return allocate_ffi_string("[]");
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// get_returns_stats
// ═════════════════════════════════════════════════════════════════════════════

FLEXISTORE_EXPORT const char* get_returns_stats(int user_id) {
    (void)user_id;

    auto& pool = DBConnectionPool::getInstance();
    ConnGuard guard{pool, pool.getConnection()};
    if (!guard.c) {
        return allocate_ffi_string("{\"total_returns\":0,\"total_refunded\":0,\"returns_today\":0}");
    }

    try {
        unique_ptr<sql::PreparedStatement> stmt(guard.c->prepareStatement(
            "SELECT "
            "  COUNT(*) AS total_returns, "
            "  CAST(COALESCE(SUM(ABS(total_amount)), 0) AS CHAR) AS total_refunded, "
            "  SUM(IF(DATE(created_at) = CURDATE(), 1, 0)) AS returns_today "
            "FROM invoices WHERE payment_type = 'return'"
        ));
        unique_ptr<sql::ResultSet> rs(stmt->executeQuery());

        JsonBuilder json;
        json.start_object();
        if (rs->next()) {
            json.add_int("total_returns", rs->getInt("total_returns"));
            double refunded = 0.0;
            try { refunded = std::stod(rs->getString("total_refunded")); } catch (...) {}
            json.add_double("total_refunded", refunded);
            json.add_int("returns_today", rs->isNull("returns_today") ? 0 : rs->getInt("returns_today"));
        } else {
            json.add_int("total_returns", 0);
            json.add_double("total_refunded", 0.0);
            json.add_int("returns_today", 0);
        }
        json.end_object();
        return allocate_ffi_string(json.build());

    } catch (sql::SQLException& e) {
        cerr << "[Returns] SQL error in get_returns_stats: " << e.what() << endl;
        return allocate_ffi_string("{\"total_returns\":0,\"total_refunded\":0,\"returns_today\":0}");
    } catch (exception& e) {
        cerr << "[Returns] Exception in get_returns_stats: " << e.what() << endl;
        return allocate_ffi_string("{\"total_returns\":0,\"total_refunded\":0,\"returns_today\":0}");
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// search_returns
// ═════════════════════════════════════════════════════════════════════════════

FLEXISTORE_EXPORT const char* search_returns(int user_id, const char* query) {
    (void)user_id;
    if (!query || query[0] == '\0') {
        return get_all_returns(user_id);
    }

    auto& pool = DBConnectionPool::getInstance();
    ConnGuard guard{pool, pool.getConnection()};
    if (!guard.c) return allocate_ffi_string("[]");

    try {
        string q = escape_like(query);
        // Try to interpret as integer for invoice_id matching
        int as_id = 0;
        try { as_id = std::stoi(query); } catch (...) {}

        string sql = BASE_RETURN_SELECT +
            " AND ( "
            "   ri.return_of_invoice_id = ? "
            "   OR ri.id = ? "
            "   OR c.name LIKE ? "
            " ) "
            "ORDER BY ri.created_at DESC LIMIT 200";

        unique_ptr<sql::PreparedStatement> stmt(guard.c->prepareStatement(sql));
        stmt->setInt(1, as_id);
        stmt->setInt(2, as_id);
        stmt->setString(3, "%" + q + "%");

        unique_ptr<sql::ResultSet> rs(stmt->executeQuery());

        JsonBuilder json;
        build_returns_array(rs.get(), json);
        return allocate_ffi_string(json.build());

    } catch (sql::SQLException& e) {
        cerr << "[Returns] SQL error in search_returns: " << e.what() << endl;
        return allocate_ffi_string("[]");
    } catch (exception& e) {
        cerr << "[Returns] Exception in search_returns: " << e.what() << endl;
        return allocate_ffi_string("[]");
    }
}

} // extern "C"
