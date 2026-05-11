#include "pos_functions.h"
#include "pos_json_parser.h"
#include "invoice_queries.h"
#include "../core/db_connection_pool.h"
#include "../core/json_builder.h"
#include "../inventory/stock_manager.h"
#include "../audit/audit_logger.h"

#include <mysql/jdbc.h>
#include <iostream>

using namespace std;
using namespace flexistore::pos;
using namespace flexistore::data;

namespace {

    // RAII guard for db connection
    struct ConnGuard {
        flexistore::DBConnectionPool& p;
        unique_ptr<sql::Connection> c;
        ~ConnGuard() { if (c) p.releaseConnection(std::move(c)); }
    };

} // anonymous namespace

extern "C" {

// ═══════════════════════════════════════════════════════════════════════════════
// pos_validate_stock
// ═══════════════════════════════════════════════════════════════════════════════

FLEXISTORE_EXPORT int pos_validate_stock(const char* items_json) {
    if (!items_json) return FFI_ERROR_INVALID_INPUT;

    auto items = parse_items_json(items_json);
    if (items.empty()) return FFI_ERROR_POS_EMPTY_CART;

    auto& pool = flexistore::DBConnectionPool::getInstance();
    ConnGuard guard{pool, pool.getConnection()};
    if (!guard.c) return FFI_ERROR_DB_CONNECTION;

    for (auto& ci : items) {
        int res = validateStock(guard.c.get(), ci.product_id, ci.quantity);
        if (res != FFI_SUCCESS) return res;
    }
    return FFI_SUCCESS;
}

// ═══════════════════════════════════════════════════════════════════════════════
// pos_process_sale — atomic transaction
// ═══════════════════════════════════════════════════════════════════════════════

FLEXISTORE_EXPORT int pos_process_sale(
    int user_id,
    int client_id,
    const char* items_json,
    double total_amount,
    double net_amount,
    const char* payment_type
) {
    if (!items_json || !payment_type) return FFI_ERROR_INVALID_INPUT;

    auto items = parse_items_json(items_json);
    if (items.empty()) return FFI_ERROR_POS_EMPTY_CART;

    auto& pool = flexistore::DBConnectionPool::getInstance();
    ConnGuard guard{pool, pool.getConnection()};
    if (!guard.c) return FFI_ERROR_DB_CONNECTION;

    sql::Connection* conn = guard.c.get();

    try {
        // ── BEGIN TRANSACTION ─────────────────────────────────────────────
        conn->setAutoCommit(false);

        // ── Step 1: Validate stock with row locks ─────────────────────────
        for (auto& ci : items) {
            int res = validateStock(conn, ci.product_id, ci.quantity);
            if (res != FFI_SUCCESS) {
                conn->rollback();
                conn->setAutoCommit(true);
                return res;
            }
        }

        // ── Step 2: Save full invoice via DAL ─────────────────────────────
        vector<InvoiceItem> dal_items;
        for (auto& ci : items) {
            dal_items.push_back({ci.product_id, ci.quantity, ci.unit_price});
        }

        int invoice_id = saveFullInvoice(conn, user_id, client_id, total_amount, net_amount, payment_type, dal_items);
        if (invoice_id <= 0) {
            conn->rollback();
            conn->setAutoCommit(true);
            return invoice_id; // saveFullInvoice returns error code directly
        }

        // ── Step 3: Deduct stock ──────────────────────────────────────────
        for (auto& ci : items) {
            int stock_result = flexistore::restock_product(ci.product_id, -ci.quantity, user_id, conn);
            if (stock_result != FFI_SUCCESS) {
                conn->rollback();
                conn->setAutoCommit(true);
                return stock_result;
            }
        }

        // ── Step 4: COMMIT ────────────────────────────────────────────────
        conn->commit();
        conn->setAutoCommit(true);

        // ── Step 5: Audit logging (outside transaction) ───────────────────
        string action_type = string("POS_") + payment_type + "_SALE";
        for (auto& ch : action_type) ch = static_cast<char>(toupper(ch));

        log_transaction(user_id, action_type.c_str(), net_amount);

        return invoice_id;

    } catch (sql::SQLException& e) {
        std::cerr << "[POS] SQLException in pos_process_sale: " << e.what() << std::endl;
        try { conn->rollback(); conn->setAutoCommit(true); } catch (...) {}
        return FFI_ERROR_DB_QUERY;
    } catch (std::exception& e) {
        std::cerr << "[POS] Exception in pos_process_sale: " << e.what() << std::endl;
        try { conn->rollback(); conn->setAutoCommit(true); } catch (...) {}
        return FFI_ERROR_UNKNOWN;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// pos_process_return — atomic return transaction
// ═══════════════════════════════════════════════════════════════════════════════

FLEXISTORE_EXPORT int pos_process_return(
    int user_id,
    int original_invoice_id,
    const char* items_json
) {
    if (original_invoice_id <= 0) return FFI_ERROR_INVALID_INPUT;

    auto& pool = flexistore::DBConnectionPool::getInstance();
    ConnGuard guard{pool, pool.getConnection()};
    if (!guard.c) return FFI_ERROR_DB_CONNECTION;

    sql::Connection* conn = guard.c.get();

    try {
        // ── BEGIN TRANSACTION ─────────────────────────────────────────────
        conn->setAutoCommit(false);

        // ── Step 1: Verify original invoice exists and is not a return ─────
        InvoiceRecord orig_inv;
        int res = findInvoiceById(conn, original_invoice_id, orig_inv);
        if (res != FFI_SUCCESS) {
            conn->rollback();
            conn->setAutoCommit(true);
            return FFI_ERROR_RET_INVOICE_NOT_FOUND;
        }

        if (orig_inv.payment_type == "return") {
            conn->rollback();
            conn->setAutoCommit(true);
            return FFI_ERROR_RET_ALREADY_RETURNED;
        }

        // ISSUE-2 FIX: Check if it has already been returned
        unique_ptr<sql::PreparedStatement> ret_check(conn->prepareStatement(
            "SELECT COUNT(*) AS c FROM invoices WHERE payment_type = 'return' AND return_of_invoice_id = ?"
        ));
        ret_check->setInt(1, original_invoice_id);
        unique_ptr<sql::ResultSet> rs_ret(ret_check->executeQuery());
        if (rs_ret->next() && rs_ret->getInt("c") > 0) {
            conn->rollback();
            conn->setAutoCommit(true);
            return FFI_ERROR_RET_ALREADY_RETURNED;
        }

        // ── Step 2: Determine which items to return ───────────────────────
        vector<CartItemData> return_items;

        if (items_json && strlen(items_json) > 2) {
            auto requested = parse_items_json(items_json);

            for (auto& req : requested) {
                bool found = false;
                for (auto& oi : orig_inv.items) {
                    if (oi.product_id == req.product_id) {
                        if (req.quantity > oi.quantity) {
                            conn->rollback(); conn->setAutoCommit(true);
                            return FFI_ERROR_RET_INVALID_QUANTITY;
                        }
                        return_items.push_back({oi.product_id, req.quantity, oi.unit_price});
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    conn->rollback(); conn->setAutoCommit(true);
                    return FFI_ERROR_RET_INVOICE_NOT_FOUND;
                }
            }
        } else {
            for (auto& oi : orig_inv.items) {
                return_items.push_back({oi.product_id, oi.quantity, oi.unit_price});
            }
        }

        if (return_items.empty()) {
            conn->rollback(); conn->setAutoCommit(true);
            return FFI_ERROR_POS_EMPTY_CART;
        }

        // ── Step 3: Create the return invoice ─────────────────────────────
        double return_total = 0.0;
        vector<InvoiceItem> dal_items;
        for (auto& ri : return_items) {
            return_total += ri.unit_price * ri.quantity;
            dal_items.push_back({ri.product_id, ri.quantity, ri.unit_price});
        }

        int return_invoice_id = saveFullInvoice(conn, user_id, orig_inv.client_id, -return_total, -return_total, "return", dal_items);
        if (return_invoice_id <= 0) {
            conn->rollback(); conn->setAutoCommit(true);
            return return_invoice_id;
        }

        // Link the return to the original invoice
        try {
            unique_ptr<sql::PreparedStatement> link_stmt(conn->prepareStatement(
                "UPDATE invoices SET return_of_invoice_id = ? WHERE id = ?"
            ));
            link_stmt->setInt(1, original_invoice_id);
            link_stmt->setInt(2, return_invoice_id);
            link_stmt->executeUpdate();
        } catch (...) {
            // Ignore error if column migration hasn't run yet, for backward compatibility
        }

        // ── Step 4: Restock items ─────────────────────────────────────────
        for (auto& ri : return_items) {
            int stock_result = flexistore::restock_product(ri.product_id, ri.quantity, user_id, conn);
            if (stock_result != FFI_SUCCESS) {
                conn->rollback();
                conn->setAutoCommit(true);
                return stock_result;
            }
        }

        // ── Step 5: COMMIT ────────────────────────────────────────────────
        conn->commit();
        conn->setAutoCommit(true);

        // ── Step 6: Audit logging ─────────────────────────────────────────
        log_transaction(user_id, "POS_RETURN", return_total);

        return return_invoice_id;

    } catch (sql::SQLException& e) {
        std::cerr << "[POS] SQLException in pos_process_return: " << e.what() << std::endl;
        try { conn->rollback(); conn->setAutoCommit(true); } catch (...) {}
        return FFI_ERROR_DB_QUERY;
    } catch (std::exception& e) {
        std::cerr << "[POS] Exception in pos_process_return: " << e.what() << std::endl;
        try { conn->rollback(); conn->setAutoCommit(true); } catch (...) {}
        return FFI_ERROR_UNKNOWN;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// pos_get_invoice — retrieve invoice + items as JSON
// ═══════════════════════════════════════════════════════════════════════════════

FLEXISTORE_EXPORT const char* pos_get_invoice(int invoice_id) {
    auto& pool = flexistore::DBConnectionPool::getInstance();
    ConnGuard guard{pool, pool.getConnection()};
    if (!guard.c) {
        return flexistore::allocate_ffi_string("{\"error\":\"DB Connection Failed\"}");
    }

    InvoiceRecord record;
    int res = findInvoiceById(guard.c.get(), invoice_id, record);
    
    if (res != FFI_SUCCESS) {
        return flexistore::allocate_ffi_string("{\"error\":\"Invoice not found\"}");
    }

    return invoiceRecordToJson(record);
}

} // extern "C"
