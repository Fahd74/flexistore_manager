#pragma once
#include "core/ffi_types.h"

extern "C" {
    // Returns JSON array of all installment plans with client info:
    // [{id, client_id, client_name, client_phone, invoice_id, total_amount,
    //   remaining_amount, months, monthly_installment, status, created_at}, ...]
    FLEXISTORE_EXPORT const char* get_all_installments();

    // Creates a new installment plan row linked to an existing invoice.
    // Returns FFI_SUCCESS or error code.
    FLEXISTORE_EXPORT int create_installment_plan(int client_id, int invoice_id,
                                                   double total_amount, int months);

    // Records a payment against an installment plan.
    // Updates remaining_amount and flips status to 'completed' when paid in full.
    // Returns FFI_SUCCESS or error code.
    FLEXISTORE_EXPORT int record_installment_payment(int installment_id,
                                                      int user_id,
                                                      double amount);
}
