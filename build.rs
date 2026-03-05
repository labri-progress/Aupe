fn main() {
    cxx_build::bridge("src/app/bitmatcher.rs")
        .file("src/bitmatcher.cc")
        .std("c++14")
        .compile("cxxbridge-aupe");

    cxx_build::bridge("src/app/bitmatcher_adaptive.rs")
        .file("src/bitmatcher_adaptive.cc")
        .std("c++14")
        .compile("cxxbridge-aupe-adaptive");

    cxx_build::bridge("src/app/bitmatcher_aging.rs")
        .file("src/bitmatcher_aging.cc")
        .std("c++14")
        .compile("cxxbridge-aupe-aging");

    println!("cargo:rerun-if-changed=src/app/bitmatcher.rs");
    println!("cargo:rerun-if-changed=src/app/bitmatcher_adaptive.rs");
    println!("cargo:rerun-if-changed=src/app/bitmatcher_aging.rs");
    println!("cargo:rerun-if-changed=src/bitmatcher.cc");
    println!("cargo:rerun-if-changed=src/bitmatcher_adaptive.cc");
    println!("cargo:rerun-if-changed=src/bitmatcher_aging.cc");
    println!("cargo:rerun-if-changed=include/bitmatcher.h");
    println!("cargo:rerun-if-changed=include/bitmatcher_adaptive.h");
    println!("cargo:rerun-if-changed=include/bitmatcher_aging.h");
}
