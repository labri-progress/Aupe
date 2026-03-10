#pragma once

#include <iostream>
#include <stdio.h>
#include <algorithm>
#include <cstring>
#include <string.h>
#include <stdlib.h>
#include "BOBHash.h"
#include <stdint.h>
//#define NDEBUG
#include <cassert>
#include <unordered_map>
#include "BOBHash.h"
#include "params.h"

#include <memory>
#include "rust/cxx.h"

#include <cmath>
#include <unordered_set>
#include <iomanip>
#include <random> 

#define ENABLE_CM_SKETCH 0
/* the bucket type macro */
#define FINGERPRINT_LENGTH 8
#define TYPE_ID_LENGTH 4

typedef struct {
	uint8_t type_id:4;
	uint8_t skip:4;
	uint8_t skip2[2];
	uint8_t fingerprint5;
	uint8_t fingerprint4;
	uint8_t fingerprint3;
	uint8_t fingerprint2;
	uint8_t fingerprint1;
} ec_bucket_type_origin;
#define define_type_5_fingerprint(type_index, c1, c2, c3, c4, c5)  typedef struct { \
		uint64_t type_id: TYPE_ID_LENGTH; \
		uint64_t count1: c1; \
		uint64_t count2: c2; \
		uint64_t count3: c3; \
		uint64_t count4: c4; \
		uint64_t count5: c5; \
		uint64_t fingerprint1: FINGERPRINT_LENGTH; \
		uint64_t fingerprint2: FINGERPRINT_LENGTH; \
		uint64_t fingerprint3: FINGERPRINT_LENGTH; \
		uint64_t fingerprint4: FINGERPRINT_LENGTH; \
		uint64_t fingerprint5: FINGERPRINT_LENGTH; \
	} ec_bucket_type##type_index;

#define define_type_4_fingerprint(type_index, c1, c2, c3, c4)  typedef struct { \
		uint64_t type_id: TYPE_ID_LENGTH; \
		uint64_t count1: c1; \
		uint64_t count2: c2; \
		uint64_t count3: c3; \
		uint64_t count4: c4; \
		uint64_t fingerprint1: FINGERPRINT_LENGTH; \
		uint64_t fingerprint2: FINGERPRINT_LENGTH; \
		uint64_t fingerprint3: FINGERPRINT_LENGTH; \
		uint64_t fingerprint4: FINGERPRINT_LENGTH; \
	} ec_bucket_type##type_index;

#define define_type_3_fingerprint(type_index, c1, c2, c3)  typedef struct { \
		uint64_t type_id: TYPE_ID_LENGTH; \
		uint64_t count1: c1; \
		uint64_t count2: c2; \
		uint64_t count3: c3; \
		uint64_t fingerprint1: FINGERPRINT_LENGTH; \
		uint64_t fingerprint2: FINGERPRINT_LENGTH; \
		uint64_t fingerprint3: FINGERPRINT_LENGTH; \
	} ec_bucket_type##type_index;

/* Each type struct */
// Store the bucket item size, each BUCKET_ITEM_SIZE[i] is a type of bucket
// BUCKET_ITEM_SIZE[0]:
//       0: bucket_type_index, i.e. the type_id of the bucket
//       5: bucket_fingerprint_size, i.e. how many fingerprints are in the bucket
//       2, 3, 4, 5, 6: the each item bit size
#define BUCKET_TYPE_NUM 12
#define FINGERPRINT_MAX_NUM 5
#define CONFIG_LENGTH (2+FINGERPRINT_MAX_NUM)
const uint8_t BUCKET_ITEM_SIZE[BUCKET_TYPE_NUM][CONFIG_LENGTH] = {
	{0, 5, 2, 3, 4, 5, 6},
	{1, 4, 3, 4, 5, 16, 0},
	{2, 4, 4, 5, 6, 13, 0},
	{3, 4, 5, 6, 7, 10, 0},
	{4, 3, 4, 5, 27, 0, 0},
	{5, 3, 5, 6, 25, 0, 0},
	{6, 3, 6, 7, 23, 0, 0},
	{7, 3, 7, 8, 21, 0, 0},
	{8, 3, 8, 9, 19, 0, 0},
	{9, 3, 9, 10, 17, 0, 0},
	{10, 3, 10, 11, 15, 0, 0},
	{11, 3, 11, 12, 13, 0, 0}
};

define_type_5_fingerprint(0, 2, 3, 4, 5, 6);
typedef union {
	uint64_t value;
	ec_bucket_type0 type_0;
	ec_bucket_type_origin type0;
} ec_bucket;

/* The item localation and  */
// const uint64_t TYPE_ID_LOC = 0; 
// const uint64_t TYPE_ID_BITMASK = (1UL << TYPE_ID_LENGTH) - 1;
#define TYPE_ID_LOC (0)
#define TYPE_ID_BITMASK ((1UL << TYPE_ID_LENGTH) - 1)
// fingerprint_loc: the start bit index of the fingerprint, [x, x+FINGERPRINT_LENGTH]
// fingerprint_loc_mask: the mask for the fingerprint
static uint8_t FINGERPRINT_LOC[FINGERPRINT_MAX_NUM];
// uint64_t FINGERPRINT_BITMASK = (1UL << FINGERPRINT_LENGTH) - 1; // The mask is 0xFF (8 bits)
#define FINGERPRINT_BITMASK ((1UL << FINGERPRINT_LENGTH) - 1)

static uint8_t COUNT_LEN[BUCKET_TYPE_NUM][FINGERPRINT_MAX_NUM];
static uint8_t _align1[4];
static uint8_t COUNT_LOC[BUCKET_TYPE_NUM][FINGERPRINT_MAX_NUM];
static uint8_t _align2[4];

#define get_bucket_type(bucket) (bucket.type0.type_id)
#define set_bucket_type(bucket, type) ((bucket).type0.type_id = (type))

static inline void init_bucket_parameters() {
	// Check the config is correct!
	assert(sizeof(ec_bucket) == 8);
	for (int i = 0; i < BUCKET_TYPE_NUM; i++) {
		const int fingerprint_num = BUCKET_ITEM_SIZE[i][1];
		int total_bit = 0;
		total_bit += TYPE_ID_LENGTH;
		total_bit += FINGERPRINT_LENGTH * fingerprint_num;
		for (int j = 2; j < 2+fingerprint_num; j++) {
			total_bit += BUCKET_ITEM_SIZE[i][j];
		}
		//printf("Type %d: fingerprint num %d, total bit %d %d\n", i, fingerprint_num, total_bit, 8 * sizeof(ec_bucket));
		assert(total_bit == 8 * sizeof(ec_bucket));
		for (int j = 2+fingerprint_num; j < CONFIG_LENGTH; j++) {
			assert(BUCKET_ITEM_SIZE[i][j] == 0);
		}
	}

	for(int i = 0; i < FINGERPRINT_MAX_NUM; i++) {
		FINGERPRINT_LOC[i] = i * FINGERPRINT_LENGTH + TYPE_ID_LENGTH;
		// FINGERPRINT_LOC[i] = 64 - (i+1) * FINGERPRINT_LENGTH; // 0-4, from the highest to smallest
	}

	for(int i = 0; i < BUCKET_TYPE_NUM; i++) {
		const int fingerprint_num = BUCKET_ITEM_SIZE[i][1];
		for (int j = 2; j < 2 + fingerprint_num; j++) {
			const int count_idx = j - 2;
			COUNT_LEN[i][count_idx] = BUCKET_ITEM_SIZE[i][j];
			if ( count_idx == 0 ) {
				COUNT_LOC[i][count_idx] = TYPE_ID_LENGTH + FINGERPRINT_LENGTH * fingerprint_num;
			} else {
				COUNT_LOC[i][count_idx] = COUNT_LOC[i][count_idx-1] + COUNT_LEN[i][count_idx-1];
			}
		}
	}
}

static inline __attribute__((always_inline)) uint32_t get_bucket_type_id(const ec_bucket* bkt) {
	return (bkt->value & (TYPE_ID_BITMASK));
}

static inline __attribute__((always_inline)) void set_bucket_type_id(ec_bucket* bkt, uint64_t type_id) {
	bkt->value = (bkt->value & ~(TYPE_ID_BITMASK)) | (type_id & TYPE_ID_BITMASK);
}

static inline __attribute__((always_inline)) uint8_t get_item_num_in_bucket_type(uint32_t type_id) {
	// return BUCKET_ITEM_SIZE[type_id][1];
	switch(type_id) {
		case 0: return 5;
		case 1 ... 3: return 4;
		case 4 ... 11: return 3;
		case 12 ... 28: return 2;
		case 29: return 1;
		default: assert(0);
		return 0; // Should never reach here
	}
}

static inline __attribute__((always_inline)) uint8_t get_bucket_fingerprint(const ec_bucket* bkt, int fingerprint_index) {
	return ((bkt->value >> FINGERPRINT_LOC[fingerprint_index]) & FINGERPRINT_BITMASK);
	// switch (fingerprint_index) {
	// 	case 0: return (bkt->type0.fingerprint1);
	// 	case 1: return (bkt->type0.fingerprint2);
	// 	case 2: return (bkt->type0.fingerprint3);
	// 	case 3: return (bkt->type0.fingerprint4);
	// 	case 4: return (bkt->type0.fingerprint5);
	// 	default: assert(0);
	// }
}

static inline __attribute__((always_inline)) void set_bucket_fingerprint(ec_bucket* bkt, int fingerprint_index, uint64_t fingerprint) {
	bkt->value = (bkt->value & ~(FINGERPRINT_BITMASK << FINGERPRINT_LOC[fingerprint_index])) | ((fingerprint & FINGERPRINT_BITMASK) << FINGERPRINT_LOC[fingerprint_index]);
	// switch (fingerprint_index) {
	// 	case 0: bkt->type0.fingerprint1 = (fingerprint & FINGERPRINT_BITMASK); break;
	// 	case 1: bkt->type0.fingerprint2 = (fingerprint & FINGERPRINT_BITMASK); break;
	// 	case 2: bkt->type0.fingerprint3 = (fingerprint & FINGERPRINT_BITMASK); break;
	// 	case 3: bkt->type0.fingerprint4 = (fingerprint & FINGERPRINT_BITMASK); break;
	// 	case 4: bkt->type0.fingerprint5 = (fingerprint & FINGERPRINT_BITMASK); break;
	// 	default: assert(0);
	// }
}

static inline __attribute__((always_inline)) uint64_t get_bucket_count(const ec_bucket* bkt, int count_index, const uint32_t type_id) {
	return (bkt->value >> COUNT_LOC[type_id][count_index]) & ((1UL << COUNT_LEN[type_id][count_index]) - 1UL);
}

static inline __attribute__((always_inline)) void set_bucket_count(ec_bucket* bkt, int count_index, uint64_t count_value, const uint32_t type_id) {
	assert(type_id < BUCKET_TYPE_NUM);
	assert(count_index < FINGERPRINT_MAX_NUM);
	bkt->value = (bkt->value & ~(((1UL << COUNT_LEN[type_id][count_index]) - 1UL) << COUNT_LOC[type_id][count_index])) | ((count_value & ((1UL << COUNT_LEN[type_id][count_index]) - 1UL)) << COUNT_LOC[type_id][count_index]);
}

/* Hash operations */
#define GET_HASH_VALUE_SENTENCE(key) int16_t final_key_len = (key_len == 0)? strlen(key): key_len;\
		h1 = (bobhash[0]->run(key, final_key_len)); \
		char s1 = (char) (h1 >> 24); \
		char s2 = (char) (h1 >> 16); \
		char s3 = (char) (h1 >> 8); \
		char s4 = (char) (h1); \
		uint8_t fp = (bobhash[1]->run(key, final_key_len));  /*(uint8_t) (s1 ^ s2 ^ s3 ^ s4);*/ \
		if (fp == 0) { \
			if ( ( s1 | s2 ) != 0 ) { fp = (s1 | s2); } \
			else if ( (s3 | s4 ) != 0) {fp = (s3 | s4);} \
			else {fp = 1;} \
			}\
		h1 = h1 % bucket_num; \
		h2 = ( h1 ^ (fp) ) % bucket_num; \
		uint hash[2] = {h1, h2};
//assert( (h1^(fp)) <= bucket_num - 1 );\
//using namespace std;
namespace org {
namespace blobstore {

// Item information structure for division operations
// bucket_id is always the hash1 (table 0 bucket index)
struct ItemInfo {
	uint8_t fingerprint;
	uint32_t bucket_id;
	uint64_t count;

	// For sorting by decreasing count
	/* bool operator<(const ItemInfo& other) const {
		return count > other.count; // Descending order
	} */

	// For sorting: decreasing count, then by bucket_id and fingerprint for determinism
	bool operator<(const ItemInfo& other) const {
		if (count != other.count) return count > other.count;
		if (bucket_id != other.bucket_id) return bucket_id < other.bucket_id;
		return fingerprint < other.fingerprint;
	}
};

class BitMatcher
{
private:
    uint bucket_num, maxloop, h1, h2;
    //ec_bucket *bucket[2];
    //BOBHash * bobhash[2];
	std::unique_ptr<BOBHash> bobhash[2];
	std::vector<ec_bucket> bucket[2];
	int error_num = 0;
    // Tracking
    uint32_t division_count = 0;
    uint32_t blocked_count = 0;

public:
    BitMatcher(uint64_t _bucket);

    void print_buckets() const;
    void copy_items_one_by_one(ec_bucket *dst, ec_bucket *src);
    void copy_items_upflow(ec_bucket *dst, ec_bucket *src);
    bool kick_to(int origin_hash_table_idx, uint32_t origin_bucket_item_idx, uint8_t fingerprint_value, uint64_t count_value);
    bool solve_overflow_locally(ec_bucket* b, const int finger_idx, const uint32_t type_id, const uint32_t table_idx, const uint32_t slot_idx);
    bool plus(ec_bucket* b, const int finger_idx, const uint32_t type_id, const uint32_t table_idx, const uint32_t slot_idx);
    //void insert(const char *key, const int16_t key_len = 0); //rust::Str key, const uint16_t key_len = 0);
    void Insert(const std::string& key, int16_t key_len);
    double zero() const;
    //double Query(const char *key, const int16_t key_len = 0);
	double Query(const std::string& key, int16_t key_len);
    int Mem(const char *key, const int16_t key_len = 0);
    double Ratio() const;
    void dump_to_file(FILE* fp);
    void Delete(char *key, const int16_t key_len = 0);

	double QueryByFp(uint8_t fingerprint_value, uint first_hash_table_idx) const;
	void InsertByFp(uint8_t fingerprint_value, uint first_hash_table_idx, uint64_t count = 1);
	//void reinsert_items_direct(const std::vector<ItemInfo>& items);
	void reinsert_items(const std::vector<ItemInfo>& items);
	std::unique_ptr<BitMatcher> clone() const;
	void merge(const BitMatcher& other);
	double LR() const;

    ~BitMatcher();

	// Tracking
	uint32_t get_division_count() const { return division_count; };
	uint32_t get_blocked_count() const { return blocked_count; };

	// Copy constructor
	BitMatcher(const BitMatcher& other);


	// Copy assignment
	BitMatcher& operator=(const BitMatcher& other);


	// Move constructor
	BitMatcher(BitMatcher&& other) noexcept;

	// Move assignment
	BitMatcher& operator=(BitMatcher&& other) noexcept;

};
std::unique_ptr<BitMatcher> new_bitmatcher(uint64_t bucket);
//std::unique_ptr<BitMatcher> BitMatcher::clone() const;

};
}