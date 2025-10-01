#include "aupe/include/bitmatcher.h"
#include "aupe/src/app/bitmatcher.rs.h"

namespace org {
namespace blobstore {


	// Copy constructor
BitMatcher::BitMatcher(const BitMatcher& other)
    : bucket_num(other.bucket_num),
      maxloop(other.maxloop),
      h1(other.h1),
      h2(other.h2)
{
    // Deep copy of bobhash
    for (int i = 0; i < 2; i++) {
        if (other.bobhash[i]) {
            bobhash[i] = std::make_unique<BOBHash>(*other.bobhash[i]);
        }
    }

    // Deep copy of buckets
    for (int i = 0; i < 2; i++) {
        bucket[i] = other.bucket[i]; // vector copy does deep copy automatically
    }
}

// Copy assignment
BitMatcher& BitMatcher::operator=(const BitMatcher& other) {
    if (this == &other) return *this;

    bucket_num = other.bucket_num;
    maxloop = other.maxloop;
    h1 = other.h1;
    h2 = other.h2;

    // Deep copy of bobhash
    for (int i = 0; i < 2; i++) {
        if (other.bobhash[i]) {
            bobhash[i] = std::make_unique<BOBHash>(*other.bobhash[i]);
        } else {
            bobhash[i].reset();
        }
    }

    // Copy buckets
    for (int i = 0; i < 2; i++) {
        bucket[i] = other.bucket[i];
    }

    return *this;
}


// Move constructor
BitMatcher::BitMatcher(BitMatcher&& other) noexcept
    : bucket_num(other.bucket_num),
      maxloop(other.maxloop),
      h1(other.h1),
      h2(other.h2)
{
    for (int i = 0; i < 2; i++) {
        bobhash[i] = std::move(other.bobhash[i]); // transfer ownership
        bucket[i] = std::move(other.bucket[i]);   // move vector
    }

    // Optionally zero-out other's simple fields
    other.bucket_num = 0;
    other.maxloop = 0;
    other.h1 = 0;
    other.h2 = 0;
}

// Move assignment
BitMatcher& BitMatcher::operator=(BitMatcher&& other) noexcept {
    if (this == &other) return *this;

    bucket_num = other.bucket_num;
    maxloop = other.maxloop;
    h1 = other.h1;
    h2 = other.h2;

    for (int i = 0; i < 2; i++) {
        bobhash[i] = std::move(other.bobhash[i]);
        bucket[i] = std::move(other.bucket[i]);
    }

    // Zero out other's simple fields
    other.bucket_num = 0;
    other.maxloop = 0;
    other.h1 = 0;
    other.h2 = 0;

    return *this;
}

std::unique_ptr<BitMatcher> new_bitmatcher(uint64_t _bucket) {
  return std::make_unique<BitMatcher>(_bucket);
}


std::unique_ptr<BitMatcher> BitMatcher::clone() const{
	return std::make_unique<BitMatcher>(*this);
}

/* BitMatcher::BitMatcher(uint64_t _bucket) {
	bucket_num = _bucket; */
BitMatcher::BitMatcher(uint64_t _bucket) : bucket_num(_bucket) {
	for (int i = 0; i < 2; i++) {
		bobhash[i] = std::make_unique<BOBHash>(i + 1000);//bobhash[i] = new BOBHash(i + 1000);
	}
	for (int i = 0; i < 2; i++) {	//initialize two arrays 
		bucket[i].resize(bucket_num); 
		/* bucket[i] = new ec_bucket[bucket_num];
		memset(bucket[i], 0, sizeof(ec_bucket) * bucket_num); */
	}
	init_bucket_parameters();
	/* printf("The bucket number is %d\n", bucket_num);
	printf("The bucket size is %d\n", (int)sizeof(ec_bucket)); */
}

void BitMatcher::print_buckets() const {
	int flag = 0;
	if (bucket_num <= 20) {
		flag = 1;
	}
	if (flag) {
        for (int i = 0; i < 2; i++) {
            printf("A %d:\n", i);
            for (uint j = 0; j < bucket_num; j++) {
                const ec_bucket* b = &bucket[i][j];  // const pointer
                const uint32_t type_id = get_bucket_type_id(b);

                printf(
                    "B %d: S=%u, fp1=%u, fp2=%u, fp3=%u, fp4=%u, fp5=%u, "
                    "count1=%lu, count2=%lu, count3=%lu, count4=%lu, count5=%lu\n",
                    j,
                    type_id,
                    get_bucket_fingerprint(b, 0),
                    get_bucket_fingerprint(b, 1),
                    get_bucket_fingerprint(b, 2),
                    get_bucket_fingerprint(b, 3),
                    get_bucket_fingerprint(b, 4),
                    get_bucket_count(b, 0, type_id),
                    get_bucket_count(b, 1, type_id),
                    get_bucket_count(b, 2, type_id),
                    get_bucket_count(b, 3, type_id),
                    get_bucket_count(b, 4, type_id)
                );
            }
        }
    } else {
        //this->Ratio();
    }
}

void BitMatcher::copy_items_one_by_one(ec_bucket *dst, ec_bucket *src) {
	const uint32_t src_type_id = get_bucket_type_id(src);
	const uint32_t dst_type_id = get_bucket_type_id(dst);
	const uint32_t item_num = get_item_num_in_bucket_type(dst_type_id);
	for (uint idx = 0; idx < item_num; idx++) {
		set_bucket_fingerprint(dst, idx, get_bucket_fingerprint(src, idx));
		set_bucket_count(dst, idx, get_bucket_count(src, idx, src_type_id), dst_type_id); 
		if ( (1UL << COUNT_LEN[dst_type_id][idx]) - 1 < get_bucket_count(src, idx, src_type_id) ) {
			printf("The dst_type_id is %d, the idx is %d, the src_type_id is %d\n", dst_type_id, idx, src_type_id);
			assert(false);
		}
	}
}

void BitMatcher::copy_items_upflow(ec_bucket *dst, ec_bucket *src) {
	const uint32_t src_type_id = get_bucket_type_id(src);
	const uint32_t dst_type_id = get_bucket_type_id(dst);
	const uint32_t item_num = get_item_num_in_bucket_type(dst_type_id);
	for (uint idx = 0; idx < item_num; idx++) {
		set_bucket_fingerprint(dst, idx, get_bucket_fingerprint(src, 1+idx));
		set_bucket_count(dst, idx, get_bucket_count(src, 1+idx, src_type_id), dst_type_id);

		if ( COUNT_LEN[dst_type_id][idx] < COUNT_LEN[src_type_id][idx + 1] ) {
			printf("The dst_type_id is %d, the idx is %d, the src_type_id is %d\n", dst_type_id, idx, src_type_id);
			assert(false);
		}
	}
}

bool BitMatcher::kick_to(int origin_hash_table_idx, uint32_t origin_bucket_item_idx, uint8_t fingerprint_value, uint64_t count_value) {
	if (fingerprint_value == 0) {
		return true;
	}
	//ec_bucket *origin_bucket = &bucket[origin_hash_table_idx][origin_bucket_item_idx];
	uint32_t new_bucket_idx = ( origin_bucket_item_idx ^ (fingerprint_value) ) % bucket_num;
	ec_bucket *dst_bucket = &bucket[1 - origin_hash_table_idx][new_bucket_idx];

	if (maxloop == 1) {
		maxloop--;
		uint32_t new_bucket_type_id = get_bucket_type_id(dst_bucket);
		uint8_t slot_num = get_item_num_in_bucket_type(new_bucket_type_id);
		for (int i = 0; i < slot_num; i++) {
			if (get_bucket_fingerprint(dst_bucket, i) == 0 &&  ( 1UL << COUNT_LEN[new_bucket_type_id][i]) - 1 > count_value) {
				set_bucket_count(dst_bucket, i, count_value, new_bucket_type_id);
				set_bucket_fingerprint(dst_bucket, i, fingerprint_value);
				return true;
			}
		}
	}
	return false;
}

bool BitMatcher::solve_overflow_locally(ec_bucket* b, const int finger_idx, const uint32_t type_id, const uint32_t table_idx, const uint32_t slot_idx) {
	for ( int i = finger_idx + 1; i < get_item_num_in_bucket_type(type_id); i++ ) {
		if ( get_bucket_fingerprint(b, i) == 0 ) {
			set_bucket_fingerprint(b, i, get_bucket_fingerprint(b, finger_idx));
			set_bucket_count(b, i, get_bucket_count(b, finger_idx, type_id), type_id);
			set_bucket_fingerprint(b, finger_idx, 0ull);
			set_bucket_count(b, finger_idx, 0, type_id);
			return true;
		}
	}
	uint64_t src_count = get_bucket_count(b, finger_idx, type_id);
	uint8_t src_fingerprint = get_bucket_fingerprint(b, finger_idx);
	for ( int dst_idx = finger_idx + 1; dst_idx < get_item_num_in_bucket_type(type_id); dst_idx++ ) {
		if ( get_bucket_count(b, dst_idx, type_id) < src_count - 1 ) {
			uint8_t dst_fingerprint = get_bucket_fingerprint(b, dst_idx);
			uint64_t dst_count = get_bucket_count(b, dst_idx, type_id);
			set_bucket_fingerprint(b, dst_idx, src_fingerprint );
			set_bucket_count(b, dst_idx, src_count, type_id);
			set_bucket_fingerprint(b, finger_idx, dst_fingerprint);
			set_bucket_count(b, finger_idx, dst_count, type_id);
			return true;
		}
	}
	ec_bucket new_bkt; new_bkt.value = 0;
	uint8_t least_finger; uint64_t least_count;
	switch (type_id) {
		case 0:
		case 3:
		{
			bool flag_need_up = false;
			uint32_t next_type_id;
			if ( finger_idx != 0 ) {
				flag_need_up = true;
				if ( type_id == 0 ) {
					next_type_id = (finger_idx == 4)? 1 : 2;
				} else {
					next_type_id = (finger_idx == 3)? 6 : 7;
				}
			}
			least_finger = get_bucket_fingerprint(b, 0);
			least_count = get_bucket_count(b, 0, type_id);
			if (flag_need_up) {
				set_bucket_type_id(&new_bkt, next_type_id);
				copy_items_upflow(&new_bkt, b);
				b->value = new_bkt.value;
			} else {
				set_bucket_fingerprint(b, 0, 0ull);
				set_bucket_count(b, 0, 0, type_id);
				assert(least_count == 3 || least_count == 31);
			}
			if ( kick_to(table_idx, slot_idx, least_finger, least_count) ) {
				return true;
			} else if ( !flag_need_up ) {
				set_bucket_fingerprint(b, 0, least_finger);
				set_bucket_count(b, 0, least_count, type_id);
				return false;
			}
			break;
		}
		case 1:
		case 2:
		{
			if (finger_idx == 3) {
				set_bucket_type_id(&new_bkt, (type_id == 1)? 4 : 5);
				least_finger = get_bucket_fingerprint(b, 0);
				least_count = get_bucket_count(b, 0, type_id);
				copy_items_upflow(&new_bkt, b);
				b->value = new_bkt.value;
				bool res = kick_to(table_idx, slot_idx, least_finger, least_count);
				if (res) {
					return true;
				} else {
					return false;
				}
			} else {
				uint32_t possible_next_type_id = (type_id == 1)? 2 : 3;
				set_bucket_type_id(&new_bkt, possible_next_type_id);
				uint32_t MAX_LEN_FOR_NEXT_TYPE = COUNT_LEN[possible_next_type_id][3];
				assert(MAX_LEN_FOR_NEXT_TYPE >= 10);
				assert(MAX_LEN_FOR_NEXT_TYPE <= 16);
				uint64_t MAX_COUNT_VALUE_FOR_NEXT = ((1ULL << MAX_LEN_FOR_NEXT_TYPE) - 2);
				if ( get_bucket_count(b, 3, type_id) <= MAX_COUNT_VALUE_FOR_NEXT ) {
					copy_items_one_by_one(&new_bkt, b);
					b->value = new_bkt.value;
					return true;
				} else {
					uint8_t out_finger = get_bucket_fingerprint(b, finger_idx);
					uint64_t out_count = get_bucket_count(b, finger_idx, type_id);
					set_bucket_fingerprint(b, finger_idx, 0ull);
					set_bucket_count(b, finger_idx, 0, type_id);
					bool res = kick_to(table_idx, slot_idx, out_finger, out_count);
					if (res) {
						return true;
					} else {
						return false;
					}
				}
			}
			break;
		}
		case 4 ... 10: 
		{
			bool go_down_enable = false;
			int possible_next_type_id = type_id + 1;
			uint32_t MAX_LEN_FOR_NEXT_TYPE = COUNT_LEN[possible_next_type_id][2];
			assert(MAX_LEN_FOR_NEXT_TYPE >= 13);
			assert(MAX_LEN_FOR_NEXT_TYPE <= 27);
			uint64_t MAX_COUNT_VALUE_FOR_NEXT = ((1ULL << MAX_LEN_FOR_NEXT_TYPE) - 2);
			if (finger_idx < 2 && get_bucket_count(b, 2, type_id) <= MAX_COUNT_VALUE_FOR_NEXT ) {
				go_down_enable = true;
				set_bucket_type_id(&new_bkt, possible_next_type_id);
				copy_items_one_by_one(&new_bkt, b);
				b->value = new_bkt.value;
				return true;
			} else {
				uint8_t out_finger = get_bucket_fingerprint(b, finger_idx);
				uint64_t out_count = get_bucket_count(b, finger_idx, type_id);
				set_bucket_fingerprint(b, finger_idx, 0ull);
				set_bucket_count(b, finger_idx, 0, type_id);
				bool kick_res =  kick_to(table_idx, slot_idx, out_finger, out_count);
				if (kick_res) {
					return true;
				} else {
					set_bucket_fingerprint(b, finger_idx, out_finger);
					set_bucket_count(b, finger_idx, 0, type_id); //out_count);
					return false;
				}
			}
			break;
		}
		case 11:
		{
			return false;
		}
		default:
			assert(false);
	}
	return false;
}

bool BitMatcher::plus(ec_bucket* b, const int finger_idx, const uint32_t type_id, const uint32_t table_idx, const uint32_t slot_idx) {
	uint64_t original_val = get_bucket_count(b, finger_idx, type_id);
	const uint64_t max_cnt_val = (1UL << COUNT_LEN[type_id][finger_idx]);
	if ( 1 + original_val == max_cnt_val ) { 
		return false;
	}
	original_val++;
	set_bucket_count(b, finger_idx, original_val, type_id);
	if ( 1 + original_val == max_cnt_val ) {
		bool res = solve_overflow_locally(b, finger_idx, type_id, table_idx, slot_idx);
		return res;
	}
	return true;
}

void BitMatcher::Insert(const std::string& key, int16_t key_len){ //rust::Str key, const uint16_t key_len) {
	maxloop = 1;		
	GET_HASH_VALUE_SENTENCE(key.c_str());
	bool flag = 0;
	int empty_jj, empty_type_id;
	ec_bucket* empty_bucket;
	for (int i = 0; i < 2; i++) {
		ec_bucket *b = bucket[i].data() + hash[i];
		uint32_t type_id = get_bucket_type_id(b);
		uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
		for (int j = fingerprint_num-1; j >= 0; j--) {
			if ( get_bucket_fingerprint(b, j) == fp ) {
				if (plus(b, j, type_id, i, hash[i])){
					//printf("plus");
				}
				return;
			} else if ( !flag && get_bucket_fingerprint(b, j) == 0) {
				empty_bucket = b;
				empty_jj = j;
				empty_type_id = type_id;
				flag = 1;
			}
		}
	}
	if (flag) {
		set_bucket_fingerprint(empty_bucket, empty_jj, fp);
		set_bucket_count(empty_bucket, empty_jj, 1, empty_type_id);
		return;
	} else {
		static int error_num = 0;
		error_num++;
		int i = fp & 0x1;
		ec_bucket *b = bucket[i].data() + hash[i];
		uint32_t type_id = get_bucket_type_id(b);
		uint32_t count = get_bucket_count(b, 0, type_id);
		if ( count == 1 && (fp & 0x2) == ((error_num & 0x1) << 1) ) {
			set_bucket_fingerprint(b, 0, fp);
			set_bucket_count(b, 0, 1, type_id);
		} else {
			set_bucket_count(b, 0, count - 1, type_id);
		}
	}
}

double BitMatcher::zero() {
	double cnt[2]={0.0, 0.0};
	for (int i=0; i<2; i++) {
		for (uint j=0; j<bucket_num; j++) {
			ec_bucket* b = bucket[i].data() + j;
			const uint64_t type_id = get_bucket_type_id(b);
			const uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
			int flag = 1;
			for (uint k=0; k< fingerprint_num; k++) {
				if ( get_bucket_fingerprint(b, k) != 0 ) { flag = 0; break; }
			}
			if (1 == flag) cnt[i]+=1;
		}
	}
	return (bucket_num-cnt[0])/bucket_num * (bucket_num-cnt[1])/bucket_num;
}

double BitMatcher::Query(const std::string& key, int16_t key_len){ //const char *key, const int16_t key_len) {
	GET_HASH_VALUE_SENTENCE(key.c_str());

	bool flag=0;
	uint64_t min_value = UINT64_MAX; uint64_t table_min[2];
	__builtin_prefetch(bucket[0].data() + hash[0], 0, 2);
	__builtin_prefetch(bucket[1].data() + hash[1], 0, 2);
	for (uint8_t i = 0; i < 2; i++) {
		ec_bucket* b = bucket[i].data() + hash[i];
		const uint32_t type_id = get_bucket_type_id(b);
		const uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
		table_min[i] = get_bucket_count(b, 0, type_id);
		for (uint8_t fpt_idx = 0; fpt_idx < fingerprint_num; fpt_idx++) {
			const uint8_t stored_fingerprint = get_bucket_fingerprint(b, fpt_idx);
			const uint64_t stored_count = get_bucket_count(b, fpt_idx, type_id);
			if ( stored_fingerprint == fp ) {
				return stored_count;
			}
			if (!flag && stored_fingerprint == 0) {
				flag = 1;
			}
			if (flag) {continue;}  
			if (stored_fingerprint != 0 && min_value > stored_count) { min_value = stored_count;}
		}
	}
	if (flag) { return 0; } 
	else {
		return min_value;
	}
}


void BitMatcher::InsertByFp(uint8_t fingerprint_value, uint first_hash_table_idx){
	maxloop = 1;		
	
	uint8_t fp = fingerprint_value;
	uint32_t h1 = first_hash_table_idx;
	uint32_t h2 = (h1 ^ fingerprint_value) % bucket_num;
	uint hash[2] = {h1, h2};

	bool flag = 0;
	int empty_jj, empty_type_id;
	ec_bucket* empty_bucket;
	for (int i = 0; i < 2; i++) {
		ec_bucket *b = bucket[i].data() + hash[i];
		uint32_t type_id = get_bucket_type_id(b);
		uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
		for (int j = fingerprint_num-1; j >= 0; j--) {
			if ( get_bucket_fingerprint(b, j) == fp ) {
				if (plus(b, j, type_id, i, hash[i])){
					//printf("plus");
				}
				return;
			} else if ( !flag && get_bucket_fingerprint(b, j) == 0) {
				empty_bucket = b;
				empty_jj = j;
				empty_type_id = type_id;
				flag = 1;
			}
		}
	}
	if (flag) {
		set_bucket_fingerprint(empty_bucket, empty_jj, fp);
		set_bucket_count(empty_bucket, empty_jj, 1, empty_type_id);
		return;
	} else {
		int error_num = 0;
		error_num++;
		int i = fp & 0x1;
		ec_bucket *b = bucket[i].data() + hash[i];
		uint32_t type_id = get_bucket_type_id(b);
		uint32_t count = get_bucket_count(b, 0, type_id);
		/* printf("Error happens when inserting fp %u to table %d, bucket %d, type %d\n", fp, i, hash[i], type_id);
		printf("The count of the first item is %lu\n", count);
		printf("fp & 0x2is %d\n", fp & 0x2);
		printf("((error_num & 0x1) << 1) is %d\n", ((error_num & 0x1) << 1)); */
		if ( count == 1 && (fp & 0x2) == ((error_num & 0x1) << 1) ) {
			set_bucket_fingerprint(b, 0, fp);
			set_bucket_count(b, 0, 1, type_id);
		} else {
			set_bucket_count(b, 0, count - 1, type_id);
		}
	}
}

double BitMatcher::QueryByFp(uint8_t fingerprint_value, uint first_hash_table_idx) const{ //const char *key, const int16_t key_len) {
	
	uint8_t fp = fingerprint_value;
	uint32_t h1 = first_hash_table_idx;
	uint32_t h2 = (h1 ^ fingerprint_value) % bucket_num;
	uint hash[2] = {h1, h2};

	bool flag=0;
	uint64_t min_value = UINT64_MAX; uint64_t table_min[2];
	__builtin_prefetch(bucket[0].data() + hash[0], 0, 2);
	__builtin_prefetch(bucket[1].data() + hash[1], 0, 2);
	for (uint8_t i = 0; i < 2; i++) {
		ec_bucket* b = const_cast<ec_bucket*>(bucket[i].data() + hash[i]);
//ec_bucket* b = bucket[i].data() + hash[i];
		const uint32_t type_id = get_bucket_type_id(b);
		const uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
		table_min[i] = get_bucket_count(b, 0, type_id);
		for (uint8_t fpt_idx = 0; fpt_idx < fingerprint_num; fpt_idx++) {
			const uint8_t stored_fingerprint = get_bucket_fingerprint(b, fpt_idx);
			const uint64_t stored_count = get_bucket_count(b, fpt_idx, type_id);
			if ( stored_fingerprint == fp ) {
				return stored_count;
			}
			if (!flag && stored_fingerprint == 0) {
				flag = 1;
			}
			if (flag) {continue;}  
			if (stored_fingerprint != 0 && min_value > stored_count) { min_value = stored_count;}
		}
	}
	if (flag) { return 0; } 
	else {
		return min_value;
	}
}


struct FingerprintKey {
    uint32_t bucket_idx;
    uint8_t fp;

    bool operator==(const FingerprintKey& other) const {
        return bucket_idx == other.bucket_idx && fp == other.fp;
    }
};

// Custom hash for unordered_set
struct FingerprintHash {
    size_t operator()(const FingerprintKey& k) const {
        return (static_cast<size_t>(k.bucket_idx) << 8) ^ k.fp;
    }
};

void BitMatcher::merge(const BitMatcher& other) {
    BitMatcher result(bucket_num);

    // Preallocate near maximum expected size (bucket_num * 5 * 4)
    std::unordered_set<FingerprintKey, FingerprintHash> all_tuples;
    all_tuples.reserve(bucket_num * 20); // 2 BitMatchers, 2 arrays per BitMatcher, 2 buckets per array and 5 counter per buckets

    auto collect = [&](const BitMatcher& bm) {
        for (int i = 0; i < 2; i++) {
            for (uint j = 0; j < bm.bucket_num; j++) {
                ec_bucket* b = const_cast<ec_bucket*>(bm.bucket[i].data() + j);
 				//const ec_bucket* b = bm.bucket[i].data() + j;
                uint32_t type_id = get_bucket_type_id(b);
                uint8_t slot_num = get_item_num_in_bucket_type(type_id);
                for (uint k = 0; k < slot_num; k++) {
                    uint8_t fp = get_bucket_fingerprint(b, k);
                    if (fp != 0) {
                        uint bucket_idx0 = j;
                        if (i != 0) {
                            bucket_idx0 = (j ^ fp) % bucket_num;
                        }
                        all_tuples.insert({bucket_idx0, fp});
                    }
                }
            }
        }
    };

    // Collect from both
    collect(*this);
    collect(other);

	//printf("all_tuples %zu\n", all_tuples.size());

    // Merge counts

	for (const auto& key : all_tuples) {
		double cnt_this  = this->QueryByFp(key.fp, key.bucket_idx);
		double cnt_other = other.QueryByFp(key.fp, key.bucket_idx);

		int mean = 0;
		double avg = (cnt_this + cnt_other) / 2.0;
		//mean = static_cast<int>(std::ceil(avg));
		if ((key.fp & 0x1) == 1 || cnt_this * cnt_other == 0) {
			mean = static_cast<int>(std::ceil(avg));
		} else {
			mean = static_cast<int>(std::floor(avg));
		}

		//printf("Merge: bucket(%u)-fp(%u) (%.1f + %.1f)/2.0 = %d\n", static_cast<unsigned>(key.bucket_idx),
		//	static_cast<unsigned>(key.fp), cnt_this, cnt_other, mean);

		for (int c = 0; c < mean; ++c) {
			result.InsertByFp(key.fp, key.bucket_idx);
		}
		//result.print_buckets();
	}
	// delte all_tuples
	all_tuples.clear();
	for (int i = 0; i < 2; i++) {
        bucket[i] = result.bucket[i];
	}
}

int BitMatcher::Mem(const char *key, const int16_t key_len) {
	GET_HASH_VALUE_SENTENCE(key);
	for (uint8_t i = 0; i < 2; i++) {
		ec_bucket* b = bucket[i].data() + hash[i];
		const uint64_t type_id = get_bucket_type_id(b);
		const uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
		for (uint8_t j = 0; j < fingerprint_num; j++) {
			const uint8_t stored_fingerprint = get_bucket_fingerprint(b, j);
			if (stored_fingerprint == fp) { return 1;}
		}
	}
	return 2;
}

double BitMatcher::Ratio() const {
    int used_num = 0;
    int total_slot = 0;
    std::unordered_map<uint16_t, uint64_t> type_count;

    for (int i = 0; i < 2; i++) {
        for (uint j = 0; j < bucket_num; j++) {
            const ec_bucket* b = &bucket[i][j];  // const pointer
            const uint32_t type_id = get_bucket_type_id(b);

            type_count[type_id]++;

            const uint32_t slot_num = get_item_num_in_bucket_type(type_id);
            total_slot += slot_num;

            const uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
            for (uint k = 0; k < fingerprint_num; k++) {
                if (get_bucket_count(b, k, type_id) != 0) {
                    used_num++;
                }
            }
        }
    }

    printf("The bucket number is %u\n", 2 * bucket_num);

    for (int i = 0; i < BUCKET_TYPE_NUM; i++) {
        if (type_count.find(i) != type_count.end()) {
            printf("type %d: %lld with ratio %.2f%%\n", 
                i, (long long)type_count[i], ((double)type_count[i]) * 100 / (2.0 * bucket_num));
        }
    }

    return used_num / static_cast<double>(total_slot);
}

void BitMatcher::dump_to_file(FILE* fp) {
	std::unordered_map<uint16_t, uint64_t> type_count;
	type_count.clear();
	for (int i = 0; i < 2; i++) {
		for (uint j = 0; j < bucket_num; j++) {
			ec_bucket* b = bucket[i].data() + j;
			const uint32_t type_id = get_bucket_type_id(b);
			const uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
			fprintf(fp, "%d\t%d\t%d\t%d\t", i, j, type_id, fingerprint_num);
			for (uint k = 0; k < fingerprint_num; k++) {
				uint32_t fingerprint = get_bucket_fingerprint(b, k);
				uint64_t cnt = get_bucket_count(b, k, type_id);
				fprintf(fp, "%d\t%llu\t", fingerprint, (unsigned long long)cnt);
			}
			fprintf(fp, "\n");
		}
	}
}

void BitMatcher::Delete(char *key, const int16_t key_len) {
	GET_HASH_VALUE_SENTENCE(key);
	for (int i = 0; i < 2; i++) {
		ec_bucket* b = bucket[i].data() + hash[i];
		const uint32_t type_id = get_bucket_type_id(b);
		const uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
		for (uint j = 0; j < fingerprint_num; j++) {
			const uint8_t stored_fingerprint = get_bucket_fingerprint(b, j);
			if (stored_fingerprint == fp) {
				uint64_t origin_value = get_bucket_count(b, j, type_id);
				set_bucket_count(b, j, origin_value - 1, type_id);
				if ( origin_value == 1 ) {
					set_bucket_fingerprint(b, j, 0ull);
				}
				return;
			}
		}
	}
}

BitMatcher::~BitMatcher() {
	/* for (int i = 0; i < 2; i++) {
		delete[]bucket[i];
	}
	for (int i = 0; i < 1; i++) {
		delete bobhash[i];
	} */
}

} // namespace blobstore
} // namespace org