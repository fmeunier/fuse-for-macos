if( /LIBSPECTRUM_DEFINE_TYPES/ ) {

  $_ = << "CODE";
#include <stdint.h>

typedef  uint8_t libspectrum_byte;
typedef   int8_t libspectrum_signed_byte;
typedef uint16_t libspectrum_word;
typedef  int16_t libspectrum_signed_word;
typedef uint32_t libspectrum_dword;
typedef  int32_t libspectrum_signed_dword;
typedef uint64_t libspectrum_qword;
typedef  int64_t libspectrum_signed_qword;
CODE
}

if( /LIBSPECTRUM_GLIB_REPLACEMENT/ ) {

  $_ = << "CODE";
#define LIBSPECTRUM_HAS_GLIB_REPLACEMENT 1

#ifndef	FALSE
#define	FALSE	(0)
#endif

#ifndef	TRUE
#define	TRUE	(!FALSE)
#endif

typedef char gchar;
typedef int gint;
typedef long glong;
typedef gint gboolean;
typedef unsigned int guint;
typedef unsigned long gulong;
typedef const void * gconstpointer;
typedef void * gpointer;

typedef struct _GSList GSList;

struct _GSList {
    gpointer data;
    GSList *next;
};

typedef void		(*GFunc)		(gpointer	data,
						 gpointer	user_data);

typedef gint		(*GCompareFunc)		(gconstpointer	a,
						 gconstpointer	b);

typedef void           (*GDestroyNotify)       (gpointer       data);

typedef void           (*GFreeFunc)            (gpointer       data);


LIBSPECTRUM_API GSList *g_slist_insert_sorted	(GSList		*list,
						 gpointer	 data,
						 GCompareFunc	 func);

LIBSPECTRUM_API GSList *g_slist_insert		(GSList		*list,
			 			 gpointer	 data,
			 			 gint		 position);

LIBSPECTRUM_API GSList *g_slist_append		(GSList		*list,
						 gpointer	 data);

LIBSPECTRUM_API GSList *g_slist_prepend		(GSList		*list,
						 gpointer	 data);

LIBSPECTRUM_API GSList *g_slist_remove		(GSList		*list,
						 gconstpointer	 data);

LIBSPECTRUM_API GSList *g_slist_last			(GSList		*list);

LIBSPECTRUM_API GSList *g_slist_reverse		(GSList		*list);

LIBSPECTRUM_API GSList *g_slist_delete_link		(GSList		*list,
				 		 GSList		*link);

LIBSPECTRUM_API guint	g_slist_length		(GSList *list);

LIBSPECTRUM_API void	g_slist_foreach			(GSList		*list,
						 GFunc		 func,
						 gpointer	 user_data);

LIBSPECTRUM_API void	g_slist_free			(GSList		*list);

LIBSPECTRUM_API GSList *g_slist_nth		(GSList		*list,
					 guint		n);

LIBSPECTRUM_API GSList *g_slist_find_custom	(GSList		*list,
					 gconstpointer	data,
					 GCompareFunc	func );

LIBSPECTRUM_API gint	g_slist_position	(GSList		*list,
					 GSList		*llink);

typedef struct _GHashTable	GHashTable;

typedef guint		(*GHashFunc)		(gconstpointer	key);

typedef void	(*GHFunc)		(gpointer	key,
						 gpointer	value,
						 gpointer	user_data);

typedef gboolean	(*GHRFunc)		(gpointer	key,
						 gpointer	value,
						 gpointer	user_data);

LIBSPECTRUM_API gint	g_int_equal (gconstpointer   v,
			       gconstpointer   v2);
LIBSPECTRUM_API guint	g_int_hash  (gconstpointer   v);

LIBSPECTRUM_API gint	g_str_equal (gconstpointer   v,
			       gconstpointer   v2);
LIBSPECTRUM_API guint	g_str_hash  (gconstpointer   v);

LIBSPECTRUM_API GHashTable *g_hash_table_new	(GHashFunc	 hash_func,
					 GCompareFunc	 key_compare_func);

LIBSPECTRUM_API GHashTable *g_hash_table_new_full (GHashFunc       hash_func,
                                             GCompareFunc    key_equal_func,
                                             GDestroyNotify  key_destroy_func,
                                             GDestroyNotify  value_destroy_func);

LIBSPECTRUM_API void	g_hash_table_destroy	(GHashTable	*hash_table);

LIBSPECTRUM_API void	g_hash_table_insert	(GHashTable	*hash_table,
					 gpointer	 key,
					 gpointer	 value);

LIBSPECTRUM_API gpointer g_hash_table_lookup	(GHashTable	*hash_table,
					 gconstpointer	 key);

LIBSPECTRUM_API void	g_hash_table_foreach (GHashTable	*hash_table,
						 GHFunc    func,
						 gpointer  user_data);

LIBSPECTRUM_API guint	g_hash_table_foreach_remove	(GHashTable	*hash_table,
						 GHRFunc	 func,
						 gpointer	 user_data);

LIBSPECTRUM_API guint	g_hash_table_size (GHashTable	*hash_table);

typedef struct _GArray GArray;

struct _GArray {
  /* Public */
  gchar *data;
  guint len;

  /* Private */
  guint element_size;
  guint allocated;
};

LIBSPECTRUM_API GArray* g_array_new( gboolean zero_terminated, gboolean clear,
		      guint element_size );
LIBSPECTRUM_API GArray* g_array_sized_new( gboolean zero_terminated, gboolean clear,
                      guint element_size, guint reserved_size );
#define g_array_append_val(a,v) g_array_append_vals( a, &(v), 1 );
LIBSPECTRUM_API GArray* g_array_append_vals( GArray *array, gconstpointer data, guint len );
#define g_array_index(a,t,i) (*(((t*)a->data)+i))
LIBSPECTRUM_API GArray* g_array_set_size( GArray *array, guint length );
LIBSPECTRUM_API GArray* g_array_remove_index_fast( GArray *array, guint index );
LIBSPECTRUM_API gchar* g_array_free( GArray *array, gboolean free_segment );

#define GINT_TO_POINTER(i)      ((gpointer)  (glong)(i))
#define GPOINTER_TO_INT(p)      ((gint)   (glong)(p))
#define GPOINTER_TO_UINT(p)     ((guint)  (gulong)(p))
CODE
}

if( /LIBSPECTRUM_INCLUDE_GCRYPT/ ) {

  $_ = << "CODE";
#include <gcrypt.h>
CODE

}

if( /LIBSPECTRUM_SIGNATURE_PARAMETERS/ ) {

  $_ = << "CODE";
  /* The DSA signature parameters 'r' and 's' */
  gcry_mpi_t r, s;
CODE

}

if( /LIBSPECTRUM_CAPABILITIES/ ) {

  $_ = << "CODE";

/* we support snapshots etc. requiring zlib (e.g. compressed szx) */
#define	LIBSPECTRUM_SUPPORTS_ZLIB_COMPRESSION	(1)

/* zlib (de)compression routines */

LIBSPECTRUM_API libspectrum_error
libspectrum_zlib_inflate( const libspectrum_byte *gzptr, size_t gzlength,
			  libspectrum_byte **outptr, size_t *outlength );

LIBSPECTRUM_API libspectrum_error
libspectrum_zlib_compress( const libspectrum_byte *data, size_t length,
			   libspectrum_byte **gzptr, size_t *gzlength );


/* we support files compressed with bz2 */
#define	LIBSPECTRUM_SUPPORTS_BZ2_COMPRESSION	(1)


/* we support wav files */
/* LIBSPECTRUM_SUPPORTS_AUDIOFILE is deprecated; use LIBSPECTRUM_SUPPORTS_WAV instead. */
#define	LIBSPECTRUM_SUPPORTS_AUDIOFILE	(1)
#define	LIBSPECTRUM_SUPPORTS_WAV	(1)

CODE
}

if( /LIBSPECTRUM_AUTOGEN_WARNING/ ) {
  $_ = << "CODE";
/* NB: This file is autogenerated from libspectrum.h.in. Do not edit
   unless you know what you're doing */
CODE
}

if( /LIBSPECTRUM_SNAP_ACCESSORS/ ) {

  open( DATAFILE, '<' . "$ENV{FUSE_DEPS_ROOT}/libspectrum/snap_accessors.txt" ) or die "Couldn't open `$ENV{FUSE_DEPS_ROOT}/libspectrum/snap_accessors.txt': $!";

  $_ = '';
  while( <DATAFILE> ) {

    # Blank lines
    next if /^\s*$/;

    # Perl comments
    next if /^\s*#/;

    # Leading C comments
    next if /^\s*\/\*/;

    # Trailing C comments
    s/\/\*(.*)\*\///;

    my( $type, $name, $indexed ) = split;

    my $return_type;
    if( $type =~ /^(.*)\*/ ) {
	$return_type = "LIBSPECTRUM_API $1 *";
    } else {
	$return_type = "LIBSPECTRUM_API $type";
    }

    if( $indexed ) {

	print << "CODE";
$return_type libspectrum_snap_$name( libspectrum_snap *snap, int idx );
LIBSPECTRUM_API void libspectrum_snap_set_$name( libspectrum_snap *snap, int idx, $type $name );
CODE

    } else {

	print << "CODE";
$return_type libspectrum_snap_$name( libspectrum_snap *snap );
LIBSPECTRUM_API void libspectrum_snap_set_$name( libspectrum_snap *snap, $type $name );
CODE

    }
  }
}

if( /LIBSPECTRUM_TAPE_ACCESSORS/ ) {

    open( DATAFILE, '<' . "$ENV{FUSE_DEPS_ROOT}/libspectrum/tape_accessors.txt" )
	or die "Couldn't open `$ENV{FUSE_DEPS_ROOT}/libspectrum/tape_accessors.txt': $!";

    $_ = '';
    while( <DATAFILE> ) {

	# Remove comments and blank lines
	s/#.*//;
	next if /^\s*$/;

	# Skip which block types each accessor applies to
	next if /^\s/;
	
	my( $type, $name, $indexed, undef ) = split;
	
	my $return_type;
	if( $type =~ /^(.*)\*/ ) {
	    $return_type = "LIBSPECTRUM_API $1 *";
	} else {
	    $return_type = "LIBSPECTRUM_API $type";
	}

	if( $indexed ) {

	  print << "CODE";
$return_type libspectrum_tape_block_$name( libspectrum_tape_block *block, size_t idx );
LIBSPECTRUM_API libspectrum_error libspectrum_tape_block_set_$name( libspectrum_tape_block *block, $type \*$name );
CODE

	} else {

	print << "CODE";
$return_type libspectrum_tape_block_$name( libspectrum_tape_block *block );
LIBSPECTRUM_API libspectrum_error libspectrum_tape_block_set_$name( libspectrum_tape_block *block, $type $name );
CODE
    
	}
    }

    close DATAFILE or die "Couldn't close `$ENV{FUSE_DEPS_ROOT}/libspectrum/tape_accessors.txt': $!";
}
