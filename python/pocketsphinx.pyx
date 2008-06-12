# Copyright (c) 2008 Carnegie Mellon University. All rights
# reserved.
#
# You may copy, modify, and distribute this code under the same terms
# as PocketSphinx or Python, at your convenience, as long as this
# notice is not removed.
#
# Author: David Huggins-Daines <dhuggins@cs.cmu.edu>

# Import SphinxBase C types
from sphinxbase cimport arg_t, cmd_ln_t, ngram_model_t, fsg_model_t, logmath_t

# Import SphinxBase extention types
from sphinxbase cimport NGramModel

# Finally, import this for SphinxBase functions (since there are too many to list)
cimport sphinxbase as sb

# PocketSphinx declarations
cdef extern from "fsg_set.h":
    ctypedef struct fsg_set_t
    ctypedef struct fsg_set_iter_t

cdef extern from "stdio.h":
    ctypedef struct FILE # oh dear...

cdef extern from "ps_lattice.h":
    ctypedef struct ps_lattice_t
    ctypedef struct ps_latnode_t
    ctypedef struct ps_latlink_t
    ctypedef struct ps_latpath_t
    ctypedef struct ps_astar_t

    ps_lattice_t *ps_lattice_retain(ps_lattice_t *dag)
    int ps_lattice_free(ps_lattice_t *dag)
    int ps_lattice_write(ps_lattice_t *dag, char *filename)

cdef extern from "pocketsphinx.h":
    ctypedef struct ps_decoder_t
    ctypedef struct ps_nbest_t
    ctypedef struct ps_seg_t
    ctypedef int size_t
    ctypedef int int32

    # I present, the relatively small and orthogonal PocketSphinx API:
    ps_decoder_t *ps_init(cmd_ln_t *config)
    int ps_reinit(ps_decoder_t *ps, cmd_ln_t *config)
    void ps_free(ps_decoder_t *ps)
    arg_t *ps_args()
    cmd_ln_t *ps_get_config(ps_decoder_t *ps)
    logmath_t *ps_get_logmath(ps_decoder_t *ps)
    ngram_model_t *ps_get_lmset(ps_decoder_t *ps)
    ngram_model_t *ps_update_lmset(ps_decoder_t *ps, ngram_model_t *lmset)
    fsg_set_t *ps_get_fsgset(ps_decoder_t *ps)
    fsg_set_t *ps_update_fsgset(ps_decoder_t *ps)
    int ps_add_word(ps_decoder_t *ps, char *word, char *phones, int update)
    int ps_decode_raw(ps_decoder_t *ps, FILE *rawfh,
                      char *uttid, size_t maxsamps)
    int ps_start_utt(ps_decoder_t *ps, char *uttid)
    int ps_process_raw(ps_decoder_t *ps, char *data, size_t n_samples,
                       int no_search, int full_utt)
    int ps_end_utt(ps_decoder_t *ps)
    char *ps_get_hyp(ps_decoder_t *ps, int32 *out_best_score, char **out_uttid)
    ps_lattice_t *ps_get_lattice(ps_decoder_t *ps)
    ps_seg_t *ps_seg_iter(ps_decoder_t *ps, int32 *out_best_score)
    ps_seg_t *ps_seg_next(ps_seg_t *seg)
    char *ps_seg_word(ps_seg_t *seg)
    void ps_seg_frames(ps_seg_t *seg, int *out_sf, int *out_ef)
    int ps_seg_prob(ps_seg_t *seg, int32 *out_ascr, int32 *out_lscr, int32 *out_lback)
    void ps_seg_free(ps_seg_t *seg)
    ps_nbest_t *ps_nbest(ps_decoder_t *ps, int sf, int ef, char *ctx1, char *ctx2)
    ps_nbest_t *ps_nbest_next(ps_nbest_t *nbest)
    char *ps_nbest_hyp(ps_nbest_t *nbest, int32 *out_score)
    ps_seg_t *ps_nbest_seg(ps_nbest_t *nbest, int32 *out_score)
    void ps_nbest_free(ps_nbest_t *nbest)
    void ps_get_utt_time(ps_decoder_t *ps, double *out_nspeech,
                         double *out_ncpu, double *out_nwall)
    void ps_get_all_time(ps_decoder_t *ps, double *out_nspeech,
                         double *out_ncpu, double *out_nwall)

# Now the fun begins.
cdef class Decoder:
    """
    PocketSphinx decoder class.

    To initialize the PocketSphinx decoder, pass a list of keyword
    arguments to the constructor:

    d = pocketsphinx.Decoder(hmm='/path/to/acoustic/model',
                             lm='/path/to/language/model',
                             dict='/path/to/dictionary',
                             beam='1e-80')
    """
    cdef ps_decoder_t *ps
    cdef char **argv
    cdef int argc

    def __cinit__(self, **kwargs):
        cdef cmd_ln_t *config
        cdef int i
        # A much more concise version of what pocketsphinx_parse_argdict used to do
        self.argc = len(kwargs) * 2
        self.argv = <char **>sb.ckd_calloc(self.argc, sizeof(char *))
        i = 0
        for k, v in kwargs.iteritems():
            if k[0] != '-':
                k = '-' + k
            self.argv[i] = sb.ckd_salloc(k)
            self.argv[i+1] = sb.ckd_salloc(v)
            i = i + 2
        config = sb.cmd_ln_parse_r(NULL, ps_args(), self.argc, self.argv, 0)
        if config == NULL:
            raise RuntimeError, "Failed to parse argument list"
        self.ps = ps_init(config)
        if self.ps == NULL:
            raise RuntimeError, "Failed to initialize PocketSphinx"

    def __dealloc__(self):
        ps_free(self.ps)
        for i from 0 <= i < self.argc:
            sb.ckd_free(self.argv[i])
        sb.ckd_free(self.argv)
        self.argv = NULL
        self.argc = 0
