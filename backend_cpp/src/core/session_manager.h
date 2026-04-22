#ifndef FLEXISTORE_SESSION_MANAGER_H
#define FLEXISTORE_SESSION_MANAGER_H

#include <string>
#include <shared_mutex>
#include "ffi_types.h"

namespace flexistore {

class SessionManager {
public:
    // ── Singleton Access ─────────────────────────────────────────────────────
    static SessionManager& get_instance();

    // Non-copyable, non-movable
    SessionManager(const SessionManager&) = delete;
    SessionManager& operator=(const SessionManager&) = delete;
    SessionManager(SessionManager&&) = delete;
    SessionManager& operator=(SessionManager&&) = delete;

    // ── Mutators ─────────────────────────────────────────────────────────────
    void set_session(int user_id, const std::string& role);
    void clear_session();

    // ── Accessors ────────────────────────────────────────────────────────────
    int get_active_user_id() const;
    std::string get_active_role() const;
    bool is_logged_in() const;

private:
    SessionManager() : current_user_id_(-1), current_role_("") {}
    ~SessionManager() = default;

    mutable std::shared_mutex mutex_;
    int current_user_id_;
    std::string current_role_;
};

} // namespace flexistore

#endif // FLEXISTORE_SESSION_MANAGER_H
