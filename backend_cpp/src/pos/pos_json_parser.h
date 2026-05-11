#ifndef FLEXISTORE_POS_JSON_PARSER_H
#define FLEXISTORE_POS_JSON_PARSER_H

#include <vector>

namespace flexistore {
namespace pos {

struct CartItemData {
    int product_id;
    int quantity;
    double unit_price;
};

// Parses a JSON array of cart items.
// Expected format: [{"product_id":1,"quantity":2,"unit_price":10.5}, ...]
std::vector<CartItemData> parse_items_json(const char* json);

} // namespace pos
} // namespace flexistore

#endif // FLEXISTORE_POS_JSON_PARSER_H
