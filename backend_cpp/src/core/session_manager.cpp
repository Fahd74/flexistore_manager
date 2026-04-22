#include "session_manager.h"
#include <mutex>

namespace flexistore {

// ═════════════════════════════════════════════════════════════════════════════
// Singleton Access
// ═════════════════════════════════════════════════════════════════════════════
SessionManager& SessionManager::get_instance() {
    static SessionManager instance;
    return instance;
}

// ═════════════════════════════════════════════════════════════════════════════
// Mutators
// ═════════════════════════════════════════════════════════════════════════════
void SessionManager::set_session(int user_id, const std::string& role) {
    std::unique_lock<std::shared_mutex> lock(mutex_);
    current_user_id_ = user_id;
    current_role_ = role;
}

void SessionManager::clear_session() {
    std::unique_lock<std::shared_mutex> lock(mutex_);
    current_user_id_ = -1;
    current_role_.clear();
}

// ═════════════════════════════════════════════════════════════════════════════
// Accessors
// ═════════════════════════════════════════════════════════════════════════════
int SessionManager::get_active_user_id() const {
    std::shared_lock<std::shared_mutex> lock(mutex_);
    return current_user_id_;
}

std::string SessionManager::get_active_role() const {
    std::shared_lock<std::shared_mutex> lock(mutex_);
    return current_role_;
}

bool SessionManager::is_logged_in() const {
    std::shared_lock<std::shared_mutex> lock(mutex_);
    return current_user_id_ != -1;
}

} // namespace flexistore
