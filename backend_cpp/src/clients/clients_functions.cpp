#include "clients_functions.h"
#include "core/db_connection_pool.h"
#include "core/json_builder.h"

#include <cppconn/prepared_statement.h>
#include <cppconn/resultset.h>
#include <cppconn/exception.h>
#include <iostream>
#include <string>

using namespace flexistore;

// ── RAII connection guard ─────────────────────────────────────────────────────
namespace {
struct ConnGuard {
    DBConnectionPool& p;
    std::unique_ptr<sql::Connection> c;
    ~ConnGuard() { if (c) p.releaseConnection(std::move(c)); }
};
} // namespace

extern "C" {

// ── get_all_clients ───────────────────────────────────────────────────────────
FLEXISTORE_EXPORT const char* get_all_clients() {
    try {
        auto& pool = DBConnectionPool::getInstance();
        auto  conn = pool.getConnection();
        if (!conn) return allocate_ffi_string("[]");
        ConnGuard g{pool, std::move(conn)};

        std::unique_ptr<sql::Statement> stmt(g.c->createStatement());
        std::unique_ptr<sql::ResultSet> rs(stmt->executeQuery(
            "SELECT id, name, phone, total_debt, created_at FROM clients ORDER BY name ASC"
        ));

        std::string json = JsonBuilder::result_set_to_json(rs.get());
        return allocate_ffi_string(json);

    } catch (const sql::SQLException& e) {
        std::cerr << "[Clients] SQLException in get_all_clients: " << e.what() << std::endl;
        return allocate_ffi_string("[]");
    } catch (...) {
        return allocate_ffi_string("[]");
    }
}

// ── add_client ────────────────────────────────────────────────────────────────
FLEXISTORE_EXPORT int add_client(const char* name, const char* phone) {
    if (!name || !phone || std::string(name).empty() || std::string(phone).empty())
        return FFI_ERROR_INVALID_INPUT;

    try {
        auto& pool = DBConnectionPool::getInstance();
        auto  conn = pool.getConnection();
        if (!conn) return FFI_ERROR_DB_CONNECTION;
        ConnGuard g{pool, std::move(conn)};

        std::unique_ptr<sql::PreparedStatement> pstmt(g.c->prepareStatement(
            "INSERT INTO clients (name, phone) VALUES (?, ?)"
        ));
        pstmt->setString(1, name);
        pstmt->setString(2, phone);
        pstmt->executeUpdate();
        return FFI_SUCCESS;

    } catch (const sql::SQLException& e) {
        std::cerr << "[Clients] SQLException in add_client: " << e.what() << std::endl;
        if (e.getErrorCode() == 1062) return FFI_ERROR_CLI_PHONE_EXISTS; // duplicate entry
        return FFI_ERROR_DB_QUERY;
    } catch (...) {
        return FFI_ERROR_UNKNOWN;
    }
}

// ── delete_client ─────────────────────────────────────────────────────────────
FLEXISTORE_EXPORT int delete_client(int client_id) {
    try {
        auto& pool = DBConnectionPool::getInstance();
        auto  conn = pool.getConnection();
        if (!conn) return FFI_ERROR_DB_CONNECTION;
        ConnGuard g{pool, std::move(conn)};

        // Guard: do not delete if client has debt
        {
            std::unique_ptr<sql::PreparedStatement> chk(g.c->prepareStatement(
                "SELECT total_debt FROM clients WHERE id = ?"
            ));
            chk->setInt(1, client_id);
            std::unique_ptr<sql::ResultSet> rs(chk->executeQuery());
            if (!rs->next()) return FFI_ERROR_NOT_FOUND;
            if (rs->getDouble("total_debt") > 0.0) return FFI_ERROR_CLI_HAS_DEBT;
        }

        std::unique_ptr<sql::PreparedStatement> del(g.c->prepareStatement(
            "DELETE FROM clients WHERE id = ?"
        ));
        del->setInt(1, client_id);
        del->executeUpdate();
        return FFI_SUCCESS;

    } catch (const sql::SQLException& e) {
        std::cerr << "[Clients] SQLException in delete_client: " << e.what() << std::endl;
        return FFI_ERROR_DB_QUERY;
    } catch (...) {
        return FFI_ERROR_UNKNOWN;
    }
}

} // extern "C"
