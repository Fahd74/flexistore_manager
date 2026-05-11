#include "pos_json_parser.h"
#include <string>

using namespace std;

namespace flexistore {
namespace pos {

void skip_ws(const char* s, size_t& pos) {
    while (s[pos] && (s[pos] == ' ' || s[pos] == '\t' ||
                    s[pos] == '\n' || s[pos] == '\r'))
        ++pos;
}

double parse_number(const char* s, size_t& pos) {
    size_t start = pos;
    if (s[pos] == '-') ++pos;
    while (s[pos] >= '0' && s[pos] <= '9') ++pos;
    if (s[pos] == '.') {
        ++pos;
        while (s[pos] >= '0' && s[pos] <= '9') ++pos;
    }
    string num_str(s + start, pos - start);
    return std::stod(num_str);
}

string parse_string(const char* s, size_t& pos) {
    if (s[pos] != '"') return "";
    ++pos; // skip opening "
    string result;
    while (s[pos] && s[pos] != '"') {
        if (s[pos] == '\\' && s[pos + 1]) {
            ++pos;
        }
        result += s[pos++];
    }
    if (s[pos] == '"') ++pos; // skip closing "
    return result;
}

vector<CartItemData> parse_items_json(const char* json) {
    vector<CartItemData> items;
    if (!json) return items;

    size_t pos = 0;
    skip_ws(json, pos);
    if (json[pos] != '[') return items;
    ++pos; // skip '['

    while (json[pos]) {
        skip_ws(json, pos);
        if (json[pos] == ']') break;
        if (json[pos] == ',') { ++pos; continue; }
        if (json[pos] != '{') break;
        ++pos; // skip '{'

        CartItemData item = {0, 0, 0.0};
        while (json[pos] && json[pos] != '}') {
            skip_ws(json, pos);
            if (json[pos] == ',') { ++pos; continue; }
            string key = parse_string(json, pos);
            skip_ws(json, pos);
            if (json[pos] == ':') ++pos;
            skip_ws(json, pos);

            if (key == "product_id") {
                item.product_id = static_cast<int>(parse_number(json, pos));
            } else if (key == "quantity") {
                item.quantity = static_cast<int>(parse_number(json, pos));
            } else if (key == "unit_price") {
                item.unit_price = parse_number(json, pos);
            } else {
                // skip unknown value (number or string)
                if (json[pos] == '"') parse_string(json, pos);
                else parse_number(json, pos);
            }
        }
        if (json[pos] == '}') ++pos;
        if (item.product_id > 0 && item.quantity > 0) {
            items.push_back(item);
        }
    }
    return items;
}

} // namespace pos
} // namespace flexistore
