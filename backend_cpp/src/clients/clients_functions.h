#pragma once
#include "core/ffi_types.h"

extern "C" {
    // Returns JSON array of all clients: [{id, name, phone, total_debt, created_at}, ...]
    FLEXISTORE_EXPORT const char* get_all_clients();

    // Add a new client. Returns FFI_SUCCESS or error code.
    FLEXISTORE_EXPORT int add_client(const char* name, const char* phone);

    // Delete client by id (only if total_debt == 0). Returns FFI_SUCCESS or error code.
    FLEXISTORE_EXPORT int delete_client(int client_id);
}
