#include "aupe/include/bitmatcher_adaptive.h"
#include "aupe/src/app/bitmatcher_adaptive.rs.h"

namespace org {
namespace blobstore {


int merge_strategy = 1; // 0 for sum, 1 for moy 2 for max

// Copy constructor
BitMatcherAdaptive::BitMatcherAdaptive(const BitMatcherAdaptive& other)
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
BitMatcherAdaptive& BitMatcherAdaptive::operator=(const BitMatcherAdaptive& other) {
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
BitMatcherAdaptive::BitMatcherAdaptive(BitMatcherAdaptive&& other) noexcept
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
BitMatcherAdaptive& BitMatcherAdaptive::operator=(BitMatcherAdaptive&& other) noexcept {
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

std::unique_ptr<BitMatcherAdaptive> new_BitMatcherAdaptive(uint64_t _bucket) {
  return std::make_unique<BitMatcherAdaptive>(_bucket);
}


std::unique_ptr<BitMatcherAdaptive> BitMatcherAdaptive::clone() const{
	return std::make_unique<BitMatcherAdaptive>(*this);
}

/* BitMatcherAdaptive::BitMatcherAdaptive(uint64_t _bucket) {
	bucket_num = _bucket; */
BitMatcherAdaptive::BitMatcherAdaptive(uint64_t _bucket) : bucket_num(_bucket) {
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

void BitMatcherAdaptive::print_buckets() const {
	
	//printf("Division count: %u\n", this->division_count);
	this->Ratio();
	return;

	printf("occupancy of %.2f%%\n", this->zero()*100);
	printf("Loading Rate of %.2f%%\n", this->LR()*100);
	int flag = 0;
	if (bucket_num <= 20) {
		flag = 1;
	}
	//flag=1;
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
        this->Ratio();
    }
}

void BitMatcherAdaptive::copy_items_one_by_one(ec_bucket *dst, ec_bucket *src) {
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

void BitMatcherAdaptive::copy_items_upflow(ec_bucket *dst, ec_bucket *src) {
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

bool BitMatcherAdaptive::kick_to(int origin_hash_table_idx, uint32_t origin_bucket_item_idx, uint8_t fingerprint_value, uint64_t count_value) {
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

bool BitMatcherAdaptive::solve_overflow_locally(ec_bucket* b, const int finger_idx, const uint32_t type_id, const uint32_t table_idx, const uint32_t slot_idx) {
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

	assert(type_id <= 3); // transition should not happen for higher type_ids

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
					this->decay(); //next_type_id = (finger_idx == 3)? 6 : 7;
					return false;
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
				// Removed assertion - count values may vary after global division
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
				this->decay();
				return false;
				/* set_bucket_type_id(&new_bkt, (type_id == 1)? 4 : 5);
				least_finger = get_bucket_fingerprint(b, 0);
				least_count = get_bucket_count(b, 0, type_id);
				copy_items_upflow(&new_bkt, b);
				b->value = new_bkt.value;
				bool res = kick_to(table_idx, slot_idx, least_finger, least_count);
				if (res) {
					return true;
				} else {
					return false;
				} */
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

bool BitMatcherAdaptive::plus(ec_bucket* b, const int finger_idx, const uint32_t type_id, const uint32_t table_idx, const uint32_t slot_idx) {
	uint64_t original_val = get_bucket_count(b, finger_idx, type_id);
	const uint64_t max_cnt_val = (1UL << COUNT_LEN[type_id][finger_idx]);
	if ( 1 + original_val == max_cnt_val ) { 
		//printf("Overflow at table %u, bucket %u, finger %d, type %u\n", table_idx, slot_idx, finger_idx, type_id);
		//printf("Current count: %lu, Max count: %lu\n", original_val, max_cnt_val - 1);
		if (type_id > 3) {
			blocked_count++;
		}
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

void BitMatcherAdaptive::Insert(const std::string& key, int16_t key_len){ //rust::Str key, const uint16_t key_len) {
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

double BitMatcherAdaptive::LR()const{ // count the number of full buckets
	double cnt[2]={0.0, 0.0};
	for (int i=0; i<2; i++) {
		for (uint j=0; j<bucket_num; j++) {
			const ec_bucket* b = bucket[i].data() + j;
			const uint64_t type_id = get_bucket_type_id(b);
			const uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
			int flag = 1;
			for (uint k=0; k< fingerprint_num; k++) {
				if ( get_bucket_fingerprint(b, k) == 0 ) { flag = 0; break; }
			}
			if (1 == flag) cnt[i]+=1;
		}
	}
	return (cnt[0]+cnt[1])/(2*bucket_num);
}

double BitMatcherAdaptive::zero()const{ // count the ratio of non full empty buckets
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
	return (bucket_num-cnt[0])/bucket_num * (bucket_num-cnt[1])/bucket_num;
}

double BitMatcherAdaptive::Query(const std::string& key, int16_t key_len){ //const char *key, const int16_t key_len) {
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


void BitMatcherAdaptive::InsertByFp(uint8_t fingerprint_value, uint first_hash_table_idx, uint64_t count){
	// Insert count incrementally to properly handle overflow using BitMatcherAdaptive's strategy
	// This allows plus() and solve_overflow_locally() to work correctly for each increment
	
	maxloop = 1;

	uint8_t fp = fingerprint_value;
	uint32_t h1 = first_hash_table_idx;
	uint32_t h2 = (h1 ^ fingerprint_value) % bucket_num;
	uint hash[2] = {h1, h2};

	for (uint64_t c = 0; c < count; c++) {
		bool flag = 0;
		int empty_jj, empty_type_id;
		ec_bucket* empty_bucket;
		for (int i = 0; i < 2; i++) {
			ec_bucket *b = bucket[i].data() + hash[i];
			uint32_t type_id = get_bucket_type_id(b);
			uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
			for (int j = fingerprint_num-1; j >= 0; j--) {
				if ( get_bucket_fingerprint(b, j) == fp ) {
					// Use plus() to increment by 1 and handle overflow properly
					if (plus(b, j, type_id, i, hash[i])){
						//printf("plus");
					}
					goto next_iteration;
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
			goto next_iteration;
		} 

		next_iteration:
		continue;
	}
}

static int find_compatible_type_a(std::vector<uint64_t>& desc_counts) {
	// Adaptive version: restrict to types 0-3 since solve_overflow_locally
	// only handles those (higher types trigger global_division instead).
	for (int t = 0; t <= 3; t++) {
		int num_slots = get_item_num_in_bucket_type(t);
		if (num_slots < (int)desc_counts.size()) continue;

		bool fits = true;
		for (int i = 0; i < (int)desc_counts.size(); i++) {
			// i-th largest count vs i-th widest slot (num_slots-1-i)
			if (desc_counts[i] > (1ULL << COUNT_LEN[t][num_slots-1-i]) - 1) { fits = false; break; }
		}
		if (fits) return t;
	}
	return -1;
}


void BitMatcherAdaptive::reinsert_items(std::vector<ItemInfo>& items) {
	for (int i = 0; i < 2; i++)
		std::fill(bucket[i].begin(), bucket[i].end(), ec_bucket{0});

		// Sort by decreasing count values
	std::sort(items.begin(), items.end());

	for (auto& item : items) {
		uint32_t hash1 = item.bucket_id;
		uint32_t hash2 = (hash1 ^ item.fingerprint) % bucket_num;
		uint32_t hashes[2] = {hash1, hash2};
		bool inserted = false;

		for (int t = 0; t < 2 && !inserted; t++) {
			ec_bucket* b = &bucket[t][hashes[t]];
			uint32_t type_id = get_bucket_type_id(b);
			uint8_t num_slots = get_item_num_in_bucket_type(type_id);

			// --- 1. Simple insertion ---
			for (int slot = (int)num_slots - 1; slot >= 0 && !inserted; slot--) {
				if (get_bucket_fingerprint(b, slot) == 0) {
					uint64_t max_cap = (1ULL << COUNT_LEN[type_id][slot]) - 1;
					if (item.count <= max_cap) {
						set_bucket_fingerprint(b, slot, item.fingerprint);
						set_bucket_count(b, slot, item.count, type_id);
						inserted = true;
					}
				}
			}
			if (inserted) break;

			// --- 2. Direct type upgrade ---
			bool has_empty = false;
			for (int slot = 0; slot < num_slots; slot++) {
				if (get_bucket_fingerprint(b, slot) == 0) { has_empty = true; break; }
			}

			if (has_empty) {
				// Collect existing items from widest slot down: already in decreasing count order.
				// New item is appended last (always smallest, since items are globally sorted desc).
				std::vector<std::pair<uint8_t, uint64_t>> all_items;
				std::vector<uint64_t> desc_counts;
				for (int slot = num_slots - 1; slot >= 0; slot--) {
					uint8_t fp = get_bucket_fingerprint(b, slot);
					if (fp != 0) {
						uint64_t cnt = get_bucket_count(b, slot, type_id);
						all_items.push_back({fp, cnt});
						desc_counts.push_back(cnt);
					}
				}
				all_items.push_back({item.fingerprint, item.count});
				desc_counts.push_back(item.count);

				int new_type = find_compatible_type_a(desc_counts);
				if (new_type >= 0) {
					int new_num_slots = get_item_num_in_bucket_type(new_type);
					b->value = 0;
					set_bucket_type_id(b, (uint64_t)new_type);
					// i-th largest item → slot (new_num_slots-1-i), the i-th widest slot
					for (int i = 0; i < (int)all_items.size(); i++) {
						int slot = new_num_slots - 1 - i;
						set_bucket_fingerprint(b, slot, all_items[i].first);
						set_bucket_count(b, slot, all_items[i].second, (uint32_t)new_type);
					}
					inserted = true;
				}
			}
		}
	}
}



double BitMatcherAdaptive::QueryByFp(uint8_t fingerprint_value, uint first_hash_table_idx) const{ //const char *key, const int16_t key_len) {
	
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


int BitMatcherAdaptive::Mem(const char *key, const int16_t key_len) {
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


double BitMatcherAdaptive::Ratio() const {
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
	//printf("division count is %llu\n", (unsigned long long)division_count);
    
    return used_num / static_cast<double>(total_slot);
}


void BitMatcherAdaptive::dump_to_file(FILE* fp) {
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

void BitMatcherAdaptive::Delete(char *key, const int16_t key_len) {
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

// Custom hash for std::pair<uint32_t, uint8_t>
struct pair_hash {
    size_t operator()(const std::pair<uint32_t, uint8_t>& p) const {
        return (static_cast<size_t>(p.first) << 8) ^ p.second;
    }
};


// Extract all items from sketch and divide their counts by 2
std::vector<ItemInfo> BitMatcherAdaptive::extract_and_divide_items() {
	std::vector<ItemInfo> items;
	items.reserve(bucket_num * 2 * 5); // Reserve space for efficiency

	// Extract from table 0 first (no hash computation needed)
	for (uint32_t i = 0; i < bucket_num; i++) {
		ec_bucket* b0 = &bucket[0][i];
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
		ec_bucket* b1 = &bucket[1][i];
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

	return items;
}

// Adaptive strategy: Global division to prevent counter overflow
void BitMatcherAdaptive::decay() {
	// Extract and divide items (inlined for efficiency)
	std::vector<ItemInfo> items = extract_and_divide_items();

	// Re-insert items into sketch (inlined for efficiency)
	reinsert_items(items);

	// Increment division counter
	division_count++;
}

// Merge two sketches with per-sketch normalization before combining.
//
// Each sketch is independently normalized by its own max count, mapped to
// the common target scale max(max_self, max_other).  This makes relative
// frequencies comparable regardless of how many global_divisions each node
// has accumulated.  After the (max) merge in normalized space the values are
// already in [0, target] and reinsert_items_direct handles the rest.
void BitMatcherAdaptive::merge(const BitMatcherAdaptive& other) {
	std::unordered_map<std::pair<uint32_t, uint8_t>, uint64_t, pair_hash> self_counts, other_counts;
	self_counts.reserve(bucket_num * 20);
	other_counts.reserve(bucket_num * 20);

	auto extract = [&](const BitMatcherAdaptive& bm,
	                   std::unordered_map<std::pair<uint32_t, uint8_t>, uint64_t, pair_hash>& out) {
		for (uint32_t i = 0; i < bm.bucket_num; i++) {
			const ec_bucket* b0 = &bm.bucket[0][i];
			uint8_t type_id = get_bucket_type_id(const_cast<ec_bucket*>(b0));
			uint8_t num_items = get_item_num_in_bucket_type(type_id);
			for (uint8_t j = 0; j < num_items; j++) {
				uint8_t fp = get_bucket_fingerprint(const_cast<ec_bucket*>(b0), j);
				if (fp == 0) continue;
				uint64_t count = get_bucket_count(const_cast<ec_bucket*>(b0), j, type_id);
				if (count > 0) out[{i, fp}] = max(out[{i, fp}], count);
			}
		}
		for (uint32_t i = 0; i < bm.bucket_num; i++) {
			const ec_bucket* b1 = &bm.bucket[1][i];
			uint8_t type_id = get_bucket_type_id(const_cast<ec_bucket*>(b1));
			uint8_t num_items = get_item_num_in_bucket_type(type_id);
			for (uint8_t j = 0; j < num_items; j++) {
				uint8_t fp = get_bucket_fingerprint(const_cast<ec_bucket*>(b1), j);
				if (fp == 0) continue;
				uint64_t count = get_bucket_count(const_cast<ec_bucket*>(b1), j, type_id);
				if (count > 0) {
					uint32_t b0_id = (i ^ fp) % bm.bucket_num;
					out[{b0_id, fp}] = max(out[{b0_id, fp}], count);
				}
			}
		}
	};

	extract(*this, self_counts);
	extract(other, other_counts);

	// Per-sketch max (normalization denominator)
	uint64_t max_self = 0, max_other = 0;
	for (const auto& kv : self_counts)  max_self  = max(max_self,  kv.second);
	for (const auto& kv : other_counts) max_other = max(max_other, kv.second);

	if (max_self == 0 && max_other == 0) return;
	if (max_self  == 0) max_self  = 1;
	if (max_other == 0) max_other = 1;

	// Common target scale: the larger of the two maxes.
	// Both sketches are mapped to [0, target], so the lower-scale one is
	// scaled up before the max comparison.
	uint64_t target = max(max_self, max_other);

	std::vector<ItemInfo> items;
	items.reserve(self_counts.size() + other_counts.size());

	for (const auto& kv : self_counts) {
		uint64_t norm_self = (kv.second * target) / max_self;
		auto it = other_counts.find(kv.first);
		uint64_t merged;
		if (it != other_counts.end()) {
			uint64_t norm_other = (it->second * target) / max_other;
			merged = (norm_self + norm_other + 1) / 2;  // average, seen by both
		} else {
			merged = (norm_self + 1) / 2;               // halved, seen by self only
		}
		if (merged > 0)
			items.push_back({kv.first.second, kv.first.first, merged});
	}
	for (const auto& kv : other_counts) {
		if (self_counts.find(kv.first) == self_counts.end()) {
			uint64_t norm_other = (kv.second * target) / max_other;
			uint64_t merged = (norm_other + 1) / 2;     // halved, seen by other only
			if (merged > 0)
				items.push_back({kv.first.second, kv.first.first, merged});
		}
	}

	std::sort(items.begin(), items.end());
	reinsert_items(items);
}

// Compute overflow count
uint32_t BitMatcherAdaptive::compute_overflow_count() const {
	uint32_t ovf_num = 0;

	for (int table = 0; table < 2; table++) {
		for (uint32_t i = 0; i < bucket_num; i++) {
			const ec_bucket* b = &bucket[table][i];
			uint8_t type_id = get_bucket_type_id(b);
			uint8_t num_items = get_item_num_in_bucket_type(type_id);

			for (uint8_t j = 0; j < num_items; j++) {
				uint64_t count = get_bucket_count(b, j, type_id);
				if (count > 0) {
					if (count == (1UL << COUNT_LEN[type_id][j]) - 1) {
						ovf_num++;
					}
				}
			}
		}
	}

	return ovf_num;
}

BitMatcherAdaptive::~BitMatcherAdaptive() {
	/* for (int i = 0; i < 2; i++) {
		delete[]bucket[i];
	}
	for (int i = 0; i < 1; i++) {
		delete bobhash[i];
	} */
}

} // namespace blobstore
} // namespace org