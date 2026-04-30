#include "pos_functions.h"
#include "core/db_connection_pool.h"
#include "core/json_builder.h"
#include "core/session_manager.h"

#include <cppconn/prepared_statement.h>
#include <cppconn/resultset.h>
#include <cppconn/statement.h>
#include <cppconn/exception.h>
#include <iostream>
#include <string>
#include <vector>
#include <sstream>

using namespace flexistore;

namespace {
struct ConnGuard {
    DBConnectionPool& p;
    std::unique_ptr<sql::Connection> c;
    ~ConnGuard() { if (c) p.releaseConnection(std::move(c)); }
};

// Minimal JSON item parser — reads product_id, quantity, unit_price from each object.
// Format: [{"product_id":1,"quantity":2,"unit_price":99.99}, ...]
struct SaleItem { int product_id; int quantity; double unit_price; };

std::vector<SaleItem> parse_items(const std::string& json) {
    std::vector<SaleItem> items;
    // Walk the JSON string manually (no external JSON lib dependency)
    size_t pos = 0;
    while ((pos = json.find('{', pos)) != std::string::npos) {
        SaleItem item{0, 0, 0.0};
        size_t end = json.find('}', pos);
        if (end == std::string::npos) break;
        std::string obj = json.substr(pos + 1, end - pos - 1);

        auto read_int = [&](const std::string& key) -> int {
            auto k = json.find("\"" + key + "\"", pos);
            if (k == std::string::npos || k > end) return 0;
            auto colon = json.find(':', k);
            if (colon == std::string::npos || colon > end) return 0;
            return std::stoi(json.substr(colon + 1));
        };
        auto read_double = [&](const std::string& key) -> double {
            auto k = json.find("\"" + key + "\"", pos);
            if (k == std::string::npos || k > end) return 0.0;
            auto colon = json.find(':', k);
            if (colon == std::string::npos || colon > end) return 0.0;
            return std::stod(json.substr(colon + 1));
        };

        item.product_id = read_int("product_id");
        item.quantity   = read_int("quantity");
        item.unit_price = read_double("unit_price");

        if (item.product_id > 0 && item.quantity > 0)
            items.push_back(item);

        pos = end + 1;
    }
    return items;
}
} // namespace

extern "C" {

// ── get_all_products ──────────────────────────────────────────────────────────
FLEXISTORE_EXPORT const char* get_all_products() {
    try {
        auto& pool = DBConnectionPool::getInstance();
        auto  conn = pool.getConnection();
        if (!conn) return allocate_ffi_string("[]");
        ConnGuard g{pool, std::move(conn)};

        std::unique_ptr<sql::Statement> stmt(g.c->createStatement());
        std::unique_ptr<sql::ResultSet> rs(stmt->executeQuery(
            "SELECT id, barcode, name, selling_price, stock_quantity, status "
            "FROM products WHERE status = 'active' ORDER BY name ASC"
        ));

        std::string json = JsonBuilder::result_set_to_json(rs.get());
        return allocate_ffi_string(json);

    } catch (const sql::SQLException& e) {
        std::cerr << "[POS] SQLException in get_all_products: " << e.what() << std::endl;
        return allocate_ffi_string("[]");
    } catch (...) {
        return allocate_ffi_string("[]");
    }
}

// ── create_sale ───────────────────────────────────────────────────────────────
// Returns new invoice_id on success (>= 1), negative error code on failure.
FLEXISTORE_EXPORT int create_sale(int user_id, int client_id,
                                   const char* items_json,
                                   const char* payment_type,
                                   double total_amount) {
    if (!items_json || !payment_type) return FFI_ERROR_INVALID_INPUT;

    std::string items_str(items_json);
    std::string pay_type(payment_type);
    auto items = parse_items(items_str);
    if (items.empty()) return FFI_ERROR_POS_EMPTY_CART;

    try {
        auto& pool = DBConnectionPool::getInstance();
        auto  conn = pool.getConnection();
        if (!conn) return FFI_ERROR_DB_CONNECTION;
        ConnGuard g{pool, std::move(conn)};

        // ── Transaction ────────────────────────────────────────────────────
        g.c->setAutoCommit(false);

        try {
            // 1. Insert invoice
            {
                std::unique_ptr<sql::PreparedStatement> pstmt(g.c->prepareStatement(
                    "INSERT INTO invoices (client_id, user_id, total_amount, net_amount, payment_type) "
                    "VALUES (?, ?, ?, ?, ?)"
                ));
                if (client_id > 0) pstmt->setInt(1, client_id);
                else               pstmt->setNull(1, sql::DataType::INTEGER);
                pstmt->setInt(2, user_id);
                pstmt->setDouble(3, total_amount);
                pstmt->setDouble(4, total_amount); // net = total for now (no discount)
                pstmt->setString(5, pay_type);
                pstmt->executeUpdate();
            }

            // 2. Get last inserted invoice id
            int invoice_id = 0;
            {
                std::unique_ptr<sql::Statement> stmt(g.c->createStatement());
                std::unique_ptr<sql::ResultSet> rs(stmt->executeQuery("SELECT LAST_INSERT_ID() AS id"));
                if (rs->next()) invoice_id = rs->getInt("id");
            }
            if (invoice_id == 0) {
                g.c->rollback();
                return FFI_ERROR_POS_INVOICE_FAILED;
            }

            // 3. Insert invoice_items + update stock
            for (auto& item : items) {
                // Check stock
                {
                    std::unique_ptr<sql::PreparedStatement> chk(g.c->prepareStatement(
                        "SELECT stock_quantity FROM products WHERE id = ? AND status = 'active'"
                    ));
                    chk->setInt(1, item.product_id);
                    std::unique_ptr<sql::ResultSet> rs(chk->executeQuery());
                    if (!rs->next() || rs->getInt("stock_quantity") < item.quantity) {
                        g.c->rollback();
                        return FFI_ERROR_POS_INSUFFICIENT_STOCK;
                    }
                }

                // Insert item
                {
                    std::unique_ptr<sql::PreparedStatement> ins(g.c->prepareStatement(
                        "INSERT INTO invoice_items (invoice_id, product_id, quantity, unit_price) "
                        "VALUES (?, ?, ?, ?)"
                    ));
                    ins->setInt(1, invoice_id);
                    ins->setInt(2, item.product_id);
                    ins->setInt(3, item.quantity);
                    ins->setDouble(4, item.unit_price);
                    ins->executeUpdate();
                }

                // Decrement stock
                {
                    std::unique_ptr<sql::PreparedStatement> upd(g.c->prepareStatement(
                        "UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?"
                    ));
                    upd->setInt(1, item.quantity);
                    upd->setInt(2, item.product_id);
                    upd->executeUpdate();
                }
            }

            g.c->commit();
            g.c->setAutoCommit(true);
            return invoice_id; // > 0 = success

        } catch (...) {
            try { g.c->rollback(); } catch (...) {}
            g.c->setAutoCommit(true);
            throw;
        }

    } catch (const sql::SQLException& e) {
        std::cerr << "[POS] SQLException in create_sale: " << e.what() << std::endl;
        return FFI_ERROR_DB_QUERY;
    } catch (...) {
        return FFI_ERROR_UNKNOWN;
    }
}

} // extern "C"
