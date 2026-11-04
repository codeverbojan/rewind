#pragma once
#include <stdint.h>
#include <stdarg.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct libvlc_instance_t libvlc_instance_t;
typedef struct libvlc_media_t libvlc_media_t;
typedef struct libvlc_media_player_t libvlc_media_player_t;
typedef struct libvlc_log_t {const char *module;} libvlc_log_t;
typedef void (*libvlc_log_cb)(void *,int,const libvlc_log_t *,const char *,va_list);
void libvlc_log_set(libvlc_instance_t *,libvlc_log_cb,void *);
void libvlc_log_unset(libvlc_instance_t *);
void libvlc_log_get_context(const libvlc_log_t *,const char **,const char **,unsigned *);
typedef enum {libvlc_NothingSpecial,libvlc_Opening,libvlc_Buffering,libvlc_Playing,libvlc_Paused,libvlc_Stopped,libvlc_Ended,libvlc_Error} libvlc_state_t;
typedef struct {int i_read_bytes,i_demux_read_bytes,i_decoded_video,i_displayed_pictures,i_decoded_audio,i_played_abuffers,i_lost_pictures;} libvlc_media_stats_t;
libvlc_instance_t *libvlc_new(int,const char *const *);
void libvlc_release(libvlc_instance_t *);
libvlc_media_t *libvlc_media_new_path(libvlc_instance_t *,const char *);
void libvlc_media_release(libvlc_media_t *);
void libvlc_media_add_option(libvlc_media_t *,const char *);
libvlc_media_player_t *libvlc_media_player_new_from_media(libvlc_media_t *);
void libvlc_media_player_stop(libvlc_media_player_t *);
void libvlc_media_player_release(libvlc_media_player_t *);
void libvlc_video_set_mouse_input(libvlc_media_player_t *,unsigned);
void libvlc_media_player_set_nsobject(libvlc_media_player_t *,void *);
void libvlc_audio_set_mute(libvlc_media_player_t *,int);
int libvlc_audio_set_volume(libvlc_media_player_t *,int);
int libvlc_video_set_spu(libvlc_media_player_t *,int);
int libvlc_media_player_play(libvlc_media_player_t *);
void libvlc_media_player_set_pause(libvlc_media_player_t *,int);
libvlc_state_t libvlc_media_player_get_state(libvlc_media_player_t *);
int libvlc_video_get_size(libvlc_media_player_t *,unsigned,unsigned *,unsigned *);
int64_t libvlc_media_player_get_time(libvlc_media_player_t *);
int libvlc_media_get_stats(libvlc_media_t *,libvlc_media_stats_t *);
#ifdef __cplusplus
}
#endif
