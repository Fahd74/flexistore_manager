#pragma once
#include "core/ffi_types.h"

extern "C" {
    // Returns JSON array of active products: [{id, barcode, name, selling_price, stock_quantity, status}, ...]
    FLEXISTORE_EXPORT const char* get_all_products();

    // Creates a complete sale: invoice + invoice_items + adjusts stock.
    // items_json format: [{"product_id":1,"quantity":2,"unit_price":99.99}, ...]
    // payment_type: "cash" | "installment"
    // Returns new invoice_id (>= 1) on success, or negative error code.
    FLEXISTORE_EXPORT int create_sale(int user_id, int client_id,
                                      const char* items_json,
                                      const char* payment_type,
                                      double total_amount);
}
