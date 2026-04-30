#pragma once
#include <memory>
namespace boost {
  template<class T> using scoped_ptr = std::unique_ptr<T>;
}
