//#pragma once
#ifndef BLOBSTORE_H
#define BLOBSTORE_H

#include "rust/cxx.h"
#include <memory>
#include "aupe/src/app/bitmatcher.rs.h"
#include <algorithm>
#include <functional>
#include <set>
#include <string>
#include <unordered_map>

namespace org {
namespace blobstore {

struct MultiBuf;
struct BlobMetadata;

class BlobstoreClient {
public:
  BlobstoreClient();
  /*uint64_t put(MultiBuf &buf) const;
  void tag(uint64_t blobid, rust::Str tag) const;
  BlobMetadata metadata(uint64_t blobid) const; */
  //BlobstoreClient() : impl(new class BlobstoreClient::impl) {}

// Upload a new blob and return a blobid that serves as a handle to the blob.
uint64_t put(MultiBuf &buf) const {
  std::string contents;

  // Traverse the caller's chunk iterator.
  //
  // In reality there might be sophisticated batching of chunks and/or parallel
  // upload implemented by the blobstore's C++ client.
  while (true) {
    auto chunk = next_chunk(buf);
    if (chunk.size() == 0) {
      break;
    }
    contents.append(reinterpret_cast<const char *>(chunk.data()), chunk.size());
  }

  // Insert into map and provide caller the handle.
  auto blobid = std::hash<std::string>{}(contents);
  impl->blobs[blobid] = {std::move(contents), {}};
  return blobid;
}

// Add tag to an existing blob.
void tag(uint64_t blobid, rust::Str tag) const {
  impl->blobs[blobid].tags.emplace(tag);
}

// Retrieve metadata about a blob.
BlobMetadata metadata(uint64_t blobid) const {
  BlobMetadata metadata{};
  auto blob = impl->blobs.find(blobid);
  if (blob != impl->blobs.end()) {
    metadata.size = blob->second.data.size();
    std::for_each(blob->second.tags.cbegin(), blob->second.tags.cend(),
                  [&](auto &t) { metadata.tags.emplace_back(t); });
  }
  return metadata;
}


private:
 /*  class impl;
  std::shared_ptr<impl> impl; */
  class impl {
  friend BlobstoreClient;
  using Blob = struct {
    std::string data;
    std::set<std::string> tags;
  };
  std::unordered_map<uint64_t, Blob> blobs;
};
std::shared_ptr<impl> impl;
};

//std::unique_ptr<BlobstoreClient> new_blobstore_client();
std::unique_ptr<BlobstoreClient> new_blobstore_client() {
  return std::make_unique<BlobstoreClient>();
}


} // namespace blobstore
} // namespace org

#endif