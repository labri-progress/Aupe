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
		bobhash[i] = std::make_unique<BOBHash>(i + 1000);
	}
	for (int i = 0; i < 2; i++) {	//initialize two arrays 
		bucket[i].resize(bucket_num); 
	}
	init_bucket_parameters();
}

void BitMatcher::print_buckets() const {
	printf("occupancy of %.2f%%\n", this->zero()*100);
	printf("number of insertions %u\n", nb_entries);
	/* int flag = 0;
	if (bucket_num <= 20) {
		flag = 1;
	}*/
	int flag=1;
	//printf("occupancy -%.2f",this->zero());
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
    } 
	this->Ratio(); 

	//else {
       /*  this->Ratio();
		this->zero();*/
    //}
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

	if (type_id >= 3) {
		// Type 3 with overflow at position 3 would transition to Type 4
		// Block this transition to maintain 4 fingerprints
		//printf("[BLOCK TRANSITION]\n");
		return false;
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
	nb_entries++;

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
				}else{
					//printf("failed to plus");//reset
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
		if ( count == 1) {// && (fp & 0x2) == ((error_num & 0x1) << 1) ) {
			set_bucket_fingerprint(b, 0, fp);
			set_bucket_count(b, 0, 1, type_id);
		} else {
			set_bucket_count(b, 0, count - 1, type_id);
		}
	}
}

double BitMatcher::zero() const{
	double cnt[2]={0.0, 0.0};
	for (int i=0; i<2; i++) {
		for (uint j=0; j<bucket_num; j++) {
			const ec_bucket* b = bucket[i].data() + j;
			const uint64_t type_id = get_bucket_type_id(b);
			const uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
			int flag = 1;
			for (uint k=0; k< fingerprint_num; k++) {
				if ( get_bucket_fingerprint(b, k) != 0 ) { flag = 0; break; }
			}
			if (1 == flag) cnt[i]+=1;
		}
	}
	//printf("occupancy %.2f-%.2f\n", (bucket_num-cnt[0])/bucket_num, (bucket_num-cnt[1])/bucket_num);
	return ((bucket_num-cnt[0]) + (bucket_num-cnt[1]))/(2*bucket_num); //(bucket_num-cnt[0])/bucket_num * (bucket_num-cnt[1])/bucket_num;
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
		if ( count == 1) { // && (fp & 0x2) == ((error_num & 0x1) << 1) ) {
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


void BitMatcher::merge(const BitMatcher& other) {
	// Custom hash function for pair<uint8_t, uint32_t>
	// Key is: (fingerprint, bucket_id) where bucket_id is always from table 0 (hash1)
	struct PairHash {
		std::size_t operator()(const std::pair<uint8_t, uint32_t>& p) const {
			return std::hash<uint8_t>()(p.first) ^ (std::hash<uint32_t>()(p.second) << 1);
		}
	};

	// Map: (fingerprint, bucket_id_table0) -> (count, in_both)
	struct ItemData {
		uint64_t count;
		bool in_both;
	};

	// Pre-reserve space for the hash map (2 BitMatchers with moderate overlap: ~15 items per bucket_num)
	std::unordered_map<std::pair<uint8_t, uint32_t>, ItemData, PairHash> items_map;
	items_map.reserve(bucket_num * 15);

	// Extract items from current BitMatcher - Table 0
	for (uint32_t i = 0; i < bucket_num; i++) {
		ec_bucket* b0 = bucket[0].data() + i;
		uint8_t type_id = get_bucket_type_id(b0);
		uint8_t num_items = get_item_num_in_bucket_type(type_id);

		for (uint8_t j = 0; j < num_items; j++) {
			uint8_t fp = get_bucket_fingerprint(b0, j);
			if (fp == 0) continue;

			uint64_t count = get_bucket_count(b0, j, type_id);
			if (count > 0) {
				items_map[std::make_pair(fp, i)] = {count, false};
			}
		}
	}

	// Extract items from current BitMatcher - Table 1
	for (uint32_t i = 0; i < bucket_num; i++) {
		ec_bucket* b1 = bucket[1].data() + i;
		uint8_t type_id = get_bucket_type_id(b1);
		uint8_t num_items = get_item_num_in_bucket_type(type_id);

		for (uint8_t j = 0; j < num_items; j++) {
			uint8_t fp = get_bucket_fingerprint(b1, j);
			if (fp == 0) continue;

			uint64_t count = get_bucket_count(b1, j, type_id);
			if (count > 0) {
				uint32_t bucket_id_table0 = (i ^ fp) % bucket_num;
				items_map[std::make_pair(fp, bucket_id_table0)] = {count, false};
			}
		}
	}

	// Extract and aggregate items from other BitMatcher - Table 0
	for (uint32_t i = 0; i < other.bucket_num; i++) {
		const ec_bucket* other_b0 = other.bucket[0].data() + i;
		uint8_t type_id = get_bucket_type_id(other_b0);
		uint8_t num_items = get_item_num_in_bucket_type(type_id);

		for (uint8_t j = 0; j < num_items; j++) {
			uint8_t fp = get_bucket_fingerprint(other_b0, j);
			if (fp == 0) continue;

			uint64_t count = get_bucket_count(other_b0, j, type_id);
			if (count > 0) {
				auto key = std::make_pair(fp, i);
				auto it = items_map.find(key);
				if (it != items_map.end()) {
					// Item exists in both - compute mean
					it->second.count = (it->second.count + count) / 2;
					it->second.in_both = true;
				} else {
					// Item only in other
					items_map[key] = {count, false};
				}
			}
		}
	}

	// Extract and aggregate items from other BitMatcher - Table 1
	for (uint32_t i = 0; i < other.bucket_num; i++) {
		const ec_bucket* other_b1 = other.bucket[1].data() + i;
		uint8_t type_id = get_bucket_type_id(other_b1);
		uint8_t num_items = get_item_num_in_bucket_type(type_id);

		for (uint8_t j = 0; j < num_items; j++) {
			uint8_t fp = get_bucket_fingerprint(other_b1, j);
			if (fp == 0) continue;

			uint64_t count = get_bucket_count(other_b1, j, type_id);
			if (count > 0) {
				uint32_t bucket_id_table0 = (i ^ fp) % bucket_num;
				auto key = std::make_pair(fp, bucket_id_table0);
				auto it = items_map.find(key);
				if (it != items_map.end()) {
					// Item exists in both - compute mean
					it->second.count = (it->second.count + count) / 2;
					it->second.in_both = true;
				} else {
					// Item only in other
					items_map[key] = {count, false};
				}
			}
		}
	}

	// Convert map to vector and apply mean division for items in only one sketch
	std::vector<ItemInfo> merged_items;
	merged_items.reserve(items_map.size());

	for (const auto& entry : items_map) {
		uint64_t count = entry.second.in_both ? entry.second.count : entry.second.count / 2;
		if (count > 0) {
			merged_items.push_back({entry.first.first, entry.first.second, count});
		}
	}

	// Sort by decreasing count
	std::sort(merged_items.begin(), merged_items.end());

	// Re-insert merged items into current sketch
	reinsert_items(merged_items);
}

void BitMatcher::decay(){
	for (int i=0; i<2; i++) {
		for (uint j=0; j<bucket_num; j++) {
			ec_bucket* b = bucket[i].data() + j;
			const uint64_t type_id = get_bucket_type_id(b);
			const uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
			for (uint k=0; k< fingerprint_num; k++) {
				uint32_t old_count = get_bucket_count(b, k, type_id);
				if (old_count != 0) {
					uint64_t new_count = old_count >> 1;
					if (new_count == 0) {
						set_bucket_count(b, k, 0, type_id);
						set_bucket_fingerprint(b, k, 0ull);
					} else {
						set_bucket_count(b, k, new_count, type_id);
					}
					/* const uint8_t stored_fingerprint = get_bucket_fingerprint(b, k);
					uint32_t new_count = 0;
					// Use floating-point division before ceil/floor
                    double half = static_cast<double>(count) / 2.0;

                    if ((stored_fingerprint & 0x1) == 1)
                        new_count = static_cast<uint32_t>(std::ceil(half));
                    else
                        new_count = static_cast<uint32_t>(std::floor(half));
                    set_bucket_count(b, k, new_count, type_id); */
                }
			}
		}
	}
}

// Extract all items from sketch and divide their counts by 2
std::vector<ItemInfo> BitMatcher::extract_and_divide_items() {
	std::vector<ItemInfo> items;
	items.reserve(bucket_num * 2 * 5); // Reserve space for efficiency

	// Extract from table 0 first (no hash computation needed)
	for (uint32_t i = 0; i < bucket_num; i++) {
		ec_bucket* b0 = bucket[0].data() + i;
		uint8_t type_id = get_bucket_type_id(b0);
		uint8_t num_items = get_item_num_in_bucket_type(type_id);

		for (uint8_t j = 0; j < num_items; j++) {
			uint8_t fp = get_bucket_fingerprint(b0, j);
			if (fp == 0) continue; // Early exit if fingerprint is 0

			uint64_t old_count = get_bucket_count(b0, j, type_id);
			if (old_count > 1) { // Only process if count > 1 (since we divide by 2)
				items.push_back({fp, i, old_count >> 1});
			}
		}
	}

	// Extract from table 1 (requires hash computation)
	for (uint32_t i = 0; i < bucket_num; i++) {
		ec_bucket* b1 = bucket[1].data() + i;
		uint8_t type_id = get_bucket_type_id(b1);
		uint8_t num_items = get_item_num_in_bucket_type(type_id);

		for (uint8_t j = 0; j < num_items; j++) {
			uint8_t fp = get_bucket_fingerprint(b1, j);
			if (fp == 0) continue; // Early exit if fingerprint is 0

			uint64_t old_count = get_bucket_count(b1, j, type_id);
			if (old_count > 1) { // Only process if count > 1 (since we divide by 2)
				// Compute hash1 = hash2 ^ fp (avoiding modulo when possible)
				uint32_t bucket_id_table0 = (i ^ fp) % bucket_num;
				items.push_back({fp, bucket_id_table0, old_count >> 1});
			}
		}
	}

	// Sort by decreasing count values
	std::sort(items.begin(), items.end());

	return items;
}

// Re-insert items into the sketch
void BitMatcher::reinsert_items(const std::vector<ItemInfo>& items) {
	// Clear both tables
	for (int i = 0; i < 2; i++) {
		for (uint j = 0; j < bucket_num; j++) {
			bucket[i][j].value = 0;
		}
	}

	// Re-insert items in sorted order to maximize capacity
	// item.bucket_id is always hash1 (table 0 bucket)
	for (const auto& item : items) {
		uint32_t hash1 = item.bucket_id;
		uint32_t hash2 = (hash1 ^ item.fingerprint) % bucket_num;

		bool inserted = false;

		// Try table 0 first
		ec_bucket* b0 = bucket[0].data() + hash1;
		uint32_t type_id0 = get_bucket_type_id(b0);
		uint8_t slot_num0 = get_item_num_in_bucket_type(type_id0);

		for (uint8_t slot = 0; slot < slot_num0; slot++) {
			if (get_bucket_fingerprint(b0, slot) == 0) {
				uint64_t max_count = (1UL << COUNT_LEN[type_id0][slot]) - 1;
				if (item.count <= max_count) {
					set_bucket_fingerprint(b0, slot, item.fingerprint);
					set_bucket_count(b0, slot, item.count, type_id0);
					inserted = true;
					break;
				}
			}
		}

		// Try table 1 if not inserted
		if (!inserted) {
			ec_bucket* b1 = bucket[1].data() + hash2;
			uint32_t type_id1 = get_bucket_type_id(b1);
			uint8_t slot_num1 = get_item_num_in_bucket_type(type_id1);

			for (uint8_t slot = 0; slot < slot_num1; slot++) {
				if (get_bucket_fingerprint(b1, slot) == 0) {
					uint64_t max_count = (1UL << COUNT_LEN[type_id1][slot]) - 1;
					if (item.count <= max_count) {
						set_bucket_fingerprint(b1, slot, item.fingerprint);
						set_bucket_count(b1, slot, item.count, type_id1);
						inserted = true;
						break;
					}
				}
			}
		}

		// If not inserted during simple reinsertion, use normal insertion
		if (!inserted) {
			// Call InsertByFp for each occurrence of this item
			for (uint64_t c = 0; c < item.count; c++) {
				InsertByFp(item.fingerprint, hash1);
			}
		}
	}
}

// Adaptive strategy: Global division to prevent counter overflow
void BitMatcher::global_division() {
	// Extract and divide items (inlined for efficiency)
	std::vector<ItemInfo> items = extract_and_divide_items();

	// Re-insert items into sketch (inlined for efficiency)
	reinsert_items(items);

	// Increment division counter
	division_count++;
}

// Compute overflow count
uint32_t BitMatcher::compute_overflow_count() const {
	uint32_t ovf_num = 0;

	for (int table = 0; table < 2; table++) {
		for (uint32_t i = 0; i < bucket_num; i++) {
			const ec_bucket* b = bucket[table].data() + i;
			uint8_t type_id = get_bucket_type_id(b);
			uint8_t num_items = get_item_num_in_bucket_type(type_id);

			for (uint8_t j = 0; j < num_items; j++) {
				uint64_t count = get_bucket_count(b, j, type_id);
				if (count > 0) {
					if (count == (1UL << COUNT_LEN[type_id][j]) - 1 ) {
						ovf_num++;
					}
				}
			}
		}
	}

	return ovf_num;
}

// add_metrics: OR (legacy function for compatibility)
double BitMatcher::compute_overflow_ratio() const {
	uint32_t total_entries = 0;
	uint32_t ovf_num = 0;

	for (int table = 0; table < 2; table++) {
		for (uint32_t i = 0; i < bucket_num; i++) {
			const ec_bucket* b = bucket[table].data() + i;
			const uint8_t type_id = get_bucket_type_id(b);
			const uint8_t num_items = get_item_num_in_bucket_type(type_id);

			for (uint8_t j = 0; j < num_items; j++) {
				uint64_t count = get_bucket_count(b, j, type_id);
				if (count > 0) {
					total_entries++;
					if (count == (1UL << COUNT_LEN[type_id][j]) - 1 ) {
						ovf_num++;
					}

				}
			}
		}
	}

	return (total_entries > 0) ? (double)ovf_num / total_entries : 0.0;
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


/* double BitMatcher::Ratio() const{
	int used_num = 0;
	int total_slot = 0;
	std::unordered_map<uint16_t, uint64_t> type_count;
	type_count.clear();
	for (int i = 0; i < 2; i++) {
		for (uint j = 0; j < bucket_num; j++) {
			const ec_bucket* b = bucket[i].data() + j;
			const uint32_t type_id = get_bucket_type_id(b);

			if (type_count.find(type_id) == type_count.end()) {
				type_count[type_id] = 1;
			} else {
				type_count[type_id]++;
			}

			const uint32_t slot_num = get_item_num_in_bucket_type(type_id);
			total_slot += slot_num;
			const uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
			for (uint k = 0; k < fingerprint_num; k++) {
				if ( get_bucket_count(b, k, type_id) != 0 ) { used_num++; }
			}
		}
	}

	printf("The bucket number is %d\n", 2*bucket_num);

	for (int i = 0;  i < BUCKET_TYPE_NUM; i++) {
		if (type_count.find(i) != type_count.end()) {
			printf("type %d: %lld with ratio %.2f%%\n", i, (long long)type_count[i], ((double) type_count[i] ) * 100 / 2.0 / bucket_num);
		}
	}

	return used_num / (total_slot * 1.0);
} */

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