#ifndef LIBSPECTRUM_WAV_INTERNALS_H
#define LIBSPECTRUM_WAV_INTERNALS_H

#include "libspectrum.h"

typedef struct libspectrum_wav_reader libspectrum_wav_reader;

/* open returns the original sample rate and frame count; the caller owns the
   reader until close. read produces mono signed samples (positive is high,
   zero/negative low), reports short reads at EOF, and never resamples. */

libspectrum_error
internal_wav_open( libspectrum_wav_reader **reader, const char *filename,
                   size_t *sample_rate, size_t *frame_count );

libspectrum_error
internal_wav_read( libspectrum_wav_reader *reader,
                   libspectrum_signed_word *buffer, size_t frames,
                   size_t *frames_read );

void
internal_wav_close( libspectrum_wav_reader *reader );

#endif
