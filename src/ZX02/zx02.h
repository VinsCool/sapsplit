/*
 * (c) Copyright 2021 by Einar Saukas. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * The name of its author may not be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#define NDEBUG 1
#define FALSE 0
#define TRUE 1

#define MAX_OFFSET_ZX02  32640
#define MAX_OFFSET_ZX102 32511
#define MAX_OFFSET_ZX202 255
#define MAX_OFFSET_FAST 2176

#define QTY_BLOCKS 10000

typedef struct block_t {
    struct block_t *chain;
    struct block_t *ghost_chain;
    int bits;
    int index;
    int offset;
    int length;
    int references;
} BLOCK;

typedef struct zx02_state_t {
    unsigned char *input_data;
    int input_size;
    int skip;
    int initial_offset;
    int backwards_mode;
    int elias_short_code;
    int elias_ending_bit;
    int zx1_mode;
    int zx2_mode;
    int offset_limit;
} zx02_state;

extern BLOCK *ghost_root;// = NULL;
extern BLOCK *dead_array;// = NULL;
extern int dead_array_size;// = 0;

extern BLOCK* addresses[QTY_BLOCKS];
extern int addressCount;// = 0;

BLOCK *allocate(int bits, int index, int offset, int length, BLOCK *chain);
void assign(BLOCK **ptr, BLOCK *chain);
BLOCK *optimize(zx02_state *s);
unsigned char *compress(BLOCK *optimal, zx02_state *s, int *output_size, int *delta);
void FlushBlocks(zx02_state* pZx02State);

