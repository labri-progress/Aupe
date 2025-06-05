fn main() {
    cxx_build::bridge("src/app/bitmatcher.rs")
        .file("src/bitmatcher.cc")
        .std("c++14")
        .compile("cxxbridge-aupe");

    println!("cargo:rerun-if-changed=src/app/bitmatcher.rs");
    println!("cargo:rerun-if-changed=src/bitmatcher.cc");
    println!("cargo:rerun-if-changed=include/bitmatcher.h");
}
