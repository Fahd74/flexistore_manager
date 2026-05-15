#ifndef FLEXISTORE_RETURNS_FUNCTIONS_H
#define FLEXISTORE_RETURNS_FUNCTIONS_H

#include "../core/ffi_types.h"

/*******************************************************************************
 * returns_functions.h — FlexiStore Manager (Team 6: Returns)
 *
 * FFI exports for the Returns module.
 *
 * Workflow:
 *   1. get_invoice_for_return()  — Fetch invoice details so the UI can show
 *                                  selectable items + quantities.
 *   2. process_return()          — Atomic return: creates return invoice,
 *                                  restocks items, reduces debt/installments
 *                                  for installment sales, audits.
 *   3. get_all_returns()         — History list for the Returns screen.
 *   4. get_returns_stats()       — Aggregate stats for the header cards.
 *   5. search_returns()          — Search history by invoice, client, etc.
 *
 * INTERNAL: process_return() wraps the existing pos_process_return() and adds
 *           debt/installment side-effects that POS team doesn't handle.
 ******************************************************************************/

extern "C" {

    /// Fetch an invoice + items for return UI. Returns JSON; "{}" if not found
    /// or already returned. Caller must free with free_ffi_string().
    FLEXISTORE_EXPORT const char* get_invoice_for_return(int user_id, int invoice_id);

    /// Process a return atomically. Returns FFI_SUCCESS (0) or a negative error.
    /// items_json: [{"product_id":N,"quantity":N,"unit_price":N}, ...]
    ///             Pass empty/null to return all items.
    FLEXISTORE_EXPORT int process_return(
        int user_id,
        int invoice_id,
        const char* items_json,
        const char* reason
    );

    /// Full return history as JSON array. Caller frees.
    FLEXISTORE_EXPORT const char* get_all_returns(int user_id);

    /// Aggregate stats {total_returns, total_refunded, returns_today}. Caller frees.
    FLEXISTORE_EXPORT const char* get_returns_stats(int user_id);

    /// Search returns by invoice_id, client name, or reason. Caller frees.
    FLEXISTORE_EXPORT const char* search_returns(int user_id, const char* query);

}

#endif // FLEXISTORE_RETURNS_FUNCTIONS_H
