#include "aupe/include/bitmatcher_aging.h"
#include "aupe/src/app/bitmatcher_aging.rs.h"

// Convenience aliases so the aging macros match the member variable names
#define get_bucket_type_id(b)          get_bucket_type_id_aging(b)
#define set_bucket_type_id(b,t)        set_bucket_type_id_aging(b,t)
#define get_item_num_in_bucket_type(t) get_item_num_in_bucket_type_aging(t)
#define get_bucket_fingerprint(b,i)    get_bucket_fingerprint_aging(b,i)
#define set_bucket_fingerprint(b,i,v)  set_bucket_fingerprint_aging(b,i,v)
#define get_bucket_count(b,i,t)        get_bucket_count_aging(b,i,t)
#define set_bucket_count(b,i,v,t)      set_bucket_count_aging(b,i,v,t)
#define COUNT_LEN                      COUNT_LEN_AGING
#define COUNT_LOC                      COUNT_LOC_AGING
#define BUCKET_TYPE_NUM                BUCKET_TYPE_NUM_AGING
#define GET_HASH_VALUE_SENTENCE(key)   GET_HASH_VALUE_SENTENCE_AGING(key)

namespace org {
namespace blobstore {

int merge_strategy_aging = 2; // 0 for sum, 1 for moy, 2 for max


	// Copy constructor
BitMatcherAging::BitMatcherAging(const BitMatcherAging& other)
    : bucket_num(other.bucket_num),
      maxloop(other.maxloop),
      h1(other.h1),
      h2(other.h2)
{
    for (int i = 0; i < 2; i++) {
        if (other.bobhash[i]) {
            bobhash[i] = std::make_unique<BOBHash>(*other.bobhash[i]);
        }
    }
    for (int i = 0; i < 2; i++) {
        bucket[i] = other.bucket[i];
    }
}

// Copy assignment
BitMatcherAging& BitMatcherAging::operator=(const BitMatcherAging& other) {
    if (this == &other) return *this;

    bucket_num = other.bucket_num;
    maxloop = other.maxloop;
    h1 = other.h1;
    h2 = other.h2;

    for (int i = 0; i < 2; i++) {
        if (other.bobhash[i]) {
            bobhash[i] = std::make_unique<BOBHash>(*other.bobhash[i]);
        } else {
            bobhash[i].reset();
        }
    }
    for (int i = 0; i < 2; i++) {
        bucket[i] = other.bucket[i];
    }

    return *this;
}


// Move constructor
BitMatcherAging::BitMatcherAging(BitMatcherAging&& other) noexcept
    : bucket_num(other.bucket_num),
      maxloop(other.maxloop),
      h1(other.h1),
      h2(other.h2)
{
    for (int i = 0; i < 2; i++) {
        bobhash[i] = std::move(other.bobhash[i]);
        bucket[i] = std::move(other.bucket[i]);
    }
    other.bucket_num = 0;
    other.maxloop = 0;
    other.h1 = 0;
    other.h2 = 0;
}

// Move assignment
BitMatcherAging& BitMatcherAging::operator=(BitMatcherAging&& other) noexcept {
    if (this == &other) return *this;

    bucket_num = other.bucket_num;
    maxloop = other.maxloop;
    h1 = other.h1;
    h2 = other.h2;

    for (int i = 0; i < 2; i++) {
        bobhash[i] = std::move(other.bobhash[i]);
        bucket[i] = std::move(other.bucket[i]);
    }
    other.bucket_num = 0;
    other.maxloop = 0;
    other.h1 = 0;
    other.h2 = 0;

    return *this;
}

std::unique_ptr<BitMatcherAging> new_BitMatcherAging(uint64_t _bucket) {
  return std::make_unique<BitMatcherAging>(_bucket);
}


std::unique_ptr<BitMatcherAging> BitMatcherAging::clone() const {
	return std::make_unique<BitMatcherAging>(*this);
}

BitMatcherAging::BitMatcherAging(uint64_t _bucket) : bucket_num(_bucket) {
	for (int i = 0; i < 2; i++) {
		bobhash[i] = std::make_unique<BOBHash>(i + 1000);
	}
	for (int i = 0; i < 2; i++) {
		bucket[i].resize(bucket_num);
	}
	init_bucket_parameters_aging();
}

void BitMatcherAging::print_buckets() const {
	this->Ratio();
	return;

	printf("occupancy of %.2f%%\n", this->zero()*100);
	printf("Loading Rate of %.2f%%\n", this->LR()*100);
	int flag = 0;
	if (bucket_num <= 20) {
		flag = 1;
	}
	if (flag) {
        for (int i = 0; i < 2; i++) {
            printf("A %d:\n", i);
            for (uint j = 0; j < bucket_num; j++) {
                const ec_bucket_aging* b = &bucket[i][j];
                const uint32_t type_id = get_bucket_type_id(b);

                printf(
                    "B %d: S=%u, fp1=%u, fp2=%u, fp3=%u, fp4=%u, fp5=%u, "
                    "count1=%lu, count2=%lu, count3=%lu, count4=%lu, count5=%lu\n",
                    j, type_id,
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

void BitMatcherAging::copy_items_one_by_one(ec_bucket_aging *dst, ec_bucket_aging *src) {
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

void BitMatcherAging::copy_items_upflow(ec_bucket_aging *dst, ec_bucket_aging *src) {
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

bool BitMatcherAging::kick_to(int origin_hash_table_idx, uint32_t origin_bucket_item_idx, uint8_t fingerprint_value, uint64_t count_value) {
	if (fingerprint_value == 0) {
		return true;
	}
	uint32_t new_bucket_idx = ( origin_bucket_item_idx ^ (fingerprint_value) ) % bucket_num;
	ec_bucket_aging *dst_bucket = &bucket[1 - origin_hash_table_idx][new_bucket_idx];

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

bool BitMatcherAging::solve_overflow_locally(ec_bucket_aging* b, const int finger_idx, const uint32_t type_id, const uint32_t table_idx, const uint32_t slot_idx) {
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
			set_bucket_fingerprint(b, dst_idx, src_fingerprint);
			set_bucket_count(b, dst_idx, src_count, type_id);
			set_bucket_fingerprint(b, finger_idx, dst_fingerprint);
			set_bucket_count(b, finger_idx, dst_count, type_id);
			return true;
		}
	}

	assert(type_id <= 3); // transition should not happen for higher type_ids

	ec_bucket_aging new_bkt; new_bkt.value = 0;
	uint8_t least_finger; uint64_t least_count;
	switch (type_id) {
		case 0:
		case 3:
		{
			if ( finger_idx != 0 ) {
				// Aging strategy: instead of shrinking the bucket from 5 to 4 slots,
				// trigger a global decay (halving) to free up counter space.
				this->decay();
				return false;
			}
			least_finger = get_bucket_fingerprint(b, 0);
			least_count = get_bucket_count(b, 0, type_id);
			set_bucket_fingerprint(b, 0, 0ull);
			set_bucket_count(b, 0, 0, type_id);
			if ( kick_to(table_idx, slot_idx, least_finger, least_count) ) {
				return true;
			} else {
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
				bool kick_res = kick_to(table_idx, slot_idx, out_finger, out_count);
				if (kick_res) {
					return true;
				} else {
					set_bucket_fingerprint(b, finger_idx, out_finger);
					set_bucket_count(b, finger_idx, 0, type_id);
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

bool BitMatcherAging::plus(ec_bucket_aging* b, const int finger_idx, const uint32_t type_id, const uint32_t table_idx, const uint32_t slot_idx) {
	uint64_t original_val = get_bucket_count(b, finger_idx, type_id);
	const uint64_t max_cnt_val = (1UL << COUNT_LEN[type_id][finger_idx]);
	if ( 1 + original_val == max_cnt_val ) {
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

void BitMatcherAging::Insert(const std::string& key, int16_t key_len) {
	maxloop = 1;
	GET_HASH_VALUE_SENTENCE(key.c_str());
	bool flag = 0;
	int empty_jj, empty_type_id;
	ec_bucket_aging* empty_bucket;

	for (int i = 0; i < 2; i++) {
		ec_bucket_aging *b = bucket[i].data() + hash[i];
		uint32_t type_id = get_bucket_type_id(b);
		uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
		for (int j = fingerprint_num-1; j >= 0; j--) {
			if ( get_bucket_fingerprint(b, j) == fp ) {
				if (plus(b, j, type_id, i, hash[i])){
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
		ec_bucket_aging *b = bucket[i].data() + hash[i];
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

double BitMatcherAging::LR() const {
	double cnt[2]={0.0, 0.0};
	for (int i=0; i<2; i++) {
		for (uint j=0; j<bucket_num; j++) {
			const ec_bucket_aging* b = bucket[i].data() + j;
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

double BitMatcherAging::zero() const {
	double cnt[2]={0.0, 0.0};
	for (int i=0; i<2; i++) {
		for (uint j=0; j<bucket_num; j++) {
			const ec_bucket_aging* b = bucket[i].data() + j;
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

double BitMatcherAging::Query(const std::string& key, int16_t key_len) {
	GET_HASH_VALUE_SENTENCE(key.c_str());

	bool flag=0;
	uint64_t min_value = UINT64_MAX; uint64_t table_min[2];
	__builtin_prefetch(bucket[0].data() + hash[0], 0, 2);
	__builtin_prefetch(bucket[1].data() + hash[1], 0, 2);
	for (uint8_t i = 0; i < 2; i++) {
		ec_bucket_aging* b = bucket[i].data() + hash[i];
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


void BitMatcherAging::InsertByFp(uint8_t fingerprint_value, uint first_hash_table_idx, uint64_t count) {
	maxloop = 1;

	uint8_t fp = fingerprint_value;
	uint32_t h1 = first_hash_table_idx;
	uint32_t h2 = (h1 ^ fingerprint_value) % bucket_num;
	uint hash[2] = {h1, h2};

	for (uint64_t c = 0; c < count; c++) {
		bool flag = 0;
		int empty_jj, empty_type_id;
		ec_bucket_aging* empty_bucket;
		for (int i = 0; i < 2; i++) {
			ec_bucket_aging *b = bucket[i].data() + hash[i];
			uint32_t type_id = get_bucket_type_id(b);
			uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
			for (int j = fingerprint_num-1; j >= 0; j--) {
				if ( get_bucket_fingerprint(b, j) == fp ) {
					if (plus(b, j, type_id, i, hash[i])){
					}
					goto next_iteration_aging;
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
			goto next_iteration_aging;
		}

		next_iteration_aging:
		continue;
	}
}

double BitMatcherAging::QueryByFp(uint8_t fingerprint_value, uint first_hash_table_idx) const {
	uint8_t fp = fingerprint_value;
	uint32_t h1 = first_hash_table_idx;
	uint32_t h2 = (h1 ^ fingerprint_value) % bucket_num;
	uint hash[2] = {h1, h2};

	bool flag=0;
	uint64_t min_value = UINT64_MAX; uint64_t table_min[2];
	__builtin_prefetch(bucket[0].data() + hash[0], 0, 2);
	__builtin_prefetch(bucket[1].data() + hash[1], 0, 2);
	for (uint8_t i = 0; i < 2; i++) {
		ec_bucket_aging* b = const_cast<ec_bucket_aging*>(bucket[i].data() + hash[i]);
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


int BitMatcherAging::Mem(const char *key, const int16_t key_len) {
	GET_HASH_VALUE_SENTENCE(key);
	for (uint8_t i = 0; i < 2; i++) {
		ec_bucket_aging* b = bucket[i].data() + hash[i];
		const uint64_t type_id = get_bucket_type_id(b);
		const uint8_t fingerprint_num = get_item_num_in_bucket_type(type_id);
		for (uint8_t j = 0; j < fingerprint_num; j++) {
			const uint8_t stored_fingerprint = get_bucket_fingerprint(b, j);
			if (stored_fingerprint == fp) { return 1;}
		}
	}
	return 2;
}


double BitMatcherAging::Ratio() const {
    int used_num = 0;
    int total_slot = 0;
    std::unordered_map<uint16_t, uint64_t> type_count;

    for (int i = 0; i < 2; i++) {
        for (uint j = 0; j < bucket_num; j++) {
            const ec_bucket_aging* b = &bucket[i][j];
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


void BitMatcherAging::dump_to_file(FILE* fp) {
	for (int i = 0; i < 2; i++) {
		for (uint j = 0; j < bucket_num; j++) {
			ec_bucket_aging* b = bucket[i].data() + j;
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

void BitMatcherAging::Delete(char *key, const int16_t key_len) {
	GET_HASH_VALUE_SENTENCE(key);
	for (int i = 0; i < 2; i++) {
		ec_bucket_aging* b = bucket[i].data() + hash[i];
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


// Custom hash for std::pair<uint32_t, uint8_t>
struct pair_hash_aging {
    size_t operator()(const std::pair<uint32_t, uint8_t>& p) const {
        return (static_cast<size_t>(p.first) << 8) ^ p.second;
    }
};


// Extract all items from sketch and divide their counts by 2
std::vector<ItemInfoAging> BitMatcherAging::extract_and_divide_items() {
	std::vector<ItemInfoAging> items;
	items.reserve(bucket_num * 2 * 5);

	for (uint32_t i = 0; i < bucket_num; i++) {
		ec_bucket_aging* b0 = &bucket[0][i];
		uint8_t type_id = get_bucket_type_id(b0);
		uint8_t num_items = get_item_num_in_bucket_type(type_id);

		for (uint8_t j = 0; j < num_items; j++) {
			uint8_t fp = get_bucket_fingerprint(b0, j);
			if (fp == 0) continue;

			uint64_t old_count = get_bucket_count(b0, j, type_id);
			if (old_count > 1) {
				items.push_back({fp, i, old_count >> 1});
			}
		}
	}

	for (uint32_t i = 0; i < bucket_num; i++) {
		ec_bucket_aging* b1 = &bucket[1][i];
		uint8_t type_id = get_bucket_type_id(b1);
		uint8_t num_items = get_item_num_in_bucket_type(type_id);

		for (uint8_t j = 0; j < num_items; j++) {
			uint8_t fp = get_bucket_fingerprint(b1, j);
			if (fp == 0) continue;

			uint64_t old_count = get_bucket_count(b1, j, type_id);
			if (old_count > 1) {
				uint32_t bucket_id_table0 = (i ^ fp) % bucket_num;
				items.push_back({fp, bucket_id_table0, old_count >> 1});
			}
		}
	}

	std::sort(items.begin(), items.end());

	return items;
}

// Re-insert items into the sketch
void BitMatcherAging::reinsert_items(const std::vector<ItemInfoAging>& items) {
	int64_t original_division_count = this->division_count;
	for (int i = 0; i < 2; i++) {
		std::fill(bucket[i].begin(), bucket[i].end(), ec_bucket_aging{0});
	}
	this->division_count = original_division_count;

	for (const auto& item : items) {
		uint32_t hash1 = item.bucket_id;

		uint32_t hash2 = (hash1 ^ item.fingerprint) % bucket_num;

		bool inserted = false;

		ec_bucket_aging* b0 = &bucket[0][hash1];
		uint32_t type_id0 = get_bucket_type_id(b0);
		uint8_t slot_num0 = get_item_num_in_bucket_type(type_id0);

		for (uint8_t slot = slot_num0; slot-- > 0; ) {
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

		if (!inserted) {
			ec_bucket_aging* b1 = &bucket[1][hash2];
			uint32_t type_id1 = get_bucket_type_id(b1);
			uint8_t slot_num1 = get_item_num_in_bucket_type(type_id1);

			for (uint8_t slot = slot_num1; slot-- > 0; ) {
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

		if (!inserted) {
			InsertByFp(item.fingerprint, hash1, item.count);
		}
	}
}


// Aging strategy: Global division to prevent counter overflow.
// Also triggered when a type-0 bucket (5 slots) would shrink to 4 slots.
void BitMatcherAging::decay() {
	std::vector<ItemInfoAging> items = extract_and_divide_items();
	reinsert_items(items);
	division_count++;
}


// Merge two BitMatcherAging sketches by accumulating and reinserting counts
void BitMatcherAging::merge(const BitMatcherAging& other) {
	std::unordered_map<std::pair<uint32_t, uint8_t>, uint64_t, pair_hash_aging> merged_counts;
	merged_counts.reserve(bucket_num * 20);

	auto extract_counts = [&](const BitMatcherAging& bm) {
		for (uint32_t i = 0; i < bm.bucket_num; i++) {
			const ec_bucket_aging* b0 = &bm.bucket[0][i];
			uint8_t type_id = get_bucket_type_id(const_cast<ec_bucket_aging*>(b0));
			uint8_t num_items = get_item_num_in_bucket_type(type_id);

			for (uint8_t j = 0; j < num_items; j++) {
				uint8_t fp = get_bucket_fingerprint(const_cast<ec_bucket_aging*>(b0), j);
				if (fp == 0) continue;

				uint64_t count = get_bucket_count(const_cast<ec_bucket_aging*>(b0), j, type_id);
				if (count > 0) {
					if (merge_strategy_aging == 0 || merge_strategy_aging == 1) {
						merged_counts[{i, fp}] += count;
					} else if (merge_strategy_aging == 2) {
						merged_counts[{i, fp}] = std::max(merged_counts[{i, fp}], count);
					}
				}
			}
		}

		for (uint32_t i = 0; i < bm.bucket_num; i++) {
			const ec_bucket_aging* b1 = &bm.bucket[1][i];
			uint8_t type_id = get_bucket_type_id(const_cast<ec_bucket_aging*>(b1));
			uint8_t num_items = get_item_num_in_bucket_type(type_id);

			for (uint8_t j = 0; j < num_items; j++) {
				uint8_t fp = get_bucket_fingerprint(const_cast<ec_bucket_aging*>(b1), j);
				if (fp == 0) continue;

				uint64_t count = get_bucket_count(const_cast<ec_bucket_aging*>(b1), j, type_id);
				if (count > 0) {
					uint32_t bucket_id_table0 = (i ^ fp) % bm.bucket_num;
					if (merge_strategy_aging == 0 || merge_strategy_aging == 1) {
						merged_counts[{bucket_id_table0, fp}] += count;
					} else if (merge_strategy_aging == 2) {
						merged_counts[{bucket_id_table0, fp}] = std::max(merged_counts[{bucket_id_table0, fp}], count);
					}
				}
			}
		}
	};

	extract_counts(*this);
	extract_counts(other);

	std::vector<ItemInfoAging> items;
	items.reserve(merged_counts.size());
	for (const auto& kv : merged_counts) {
		int count = kv.second;
		if (merge_strategy_aging == 1) {
			count = (count + 1) / 2;
		}
		items.push_back({kv.first.second, kv.first.first, count});
	}
	std::sort(items.begin(), items.end());

	reinsert_items(items);
}

// Compute overflow count
uint32_t BitMatcherAging::compute_overflow_count() const {
	uint32_t ovf_num = 0;

	for (int table = 0; table < 2; table++) {
		for (uint32_t i = 0; i < bucket_num; i++) {
			const ec_bucket_aging* b = &bucket[table][i];
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

BitMatcherAging::~BitMatcherAging() {
}

} // namespace blobstore
} // namespace org
