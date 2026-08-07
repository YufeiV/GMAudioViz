# SPDX-License-Identifier: GPL-2.0-or-later

if(NOT DEFINED SNDFILE_SOURCE)
    message(FATAL_ERROR "SNDFILE_SOURCE must point to the libsndfile source directory")
endif()

function(replace_text file old_text new_text)
    file(READ "${file}" content)
    string(REPLACE "\r\n" "\n" content "${content}")
    string(FIND "${content}" "${old_text}" old_index)
    if(old_index GREATER -1)
        string(REPLACE "${old_text}" "${new_text}" content "${content}")
        file(WRITE "${file}" "${content}")
    else()
        string(FIND "${content}" "${new_text}" new_index)
        if(new_index EQUAL -1)
            message(FATAL_ERROR "Could not patch ${file}: expected text was not found")
        endif()
    endif()
endfunction()

set(checks_file "${SNDFILE_SOURCE}/cmake/SndFileChecks.cmake")
set(_old [=[if (Vorbis_FOUND AND FLAC_FOUND AND Opus_FOUND)
	set (HAVE_EXTERNAL_XIPH_LIBS 1)
else ()
	set (HAVE_EXTERNAL_XIPH_LIBS 0)
endif ()]=])
set(_new [=[if (Ogg_FOUND AND Vorbis_FOUND)
	set (HAVE_EXTERNAL_XIPH_LIBS 1)
else ()
	set (HAVE_EXTERNAL_XIPH_LIBS 0)
endif ()
if (FLAC_FOUND AND TARGET FLAC::FLAC)
	set (HAVE_FLAC 1)
else ()
	set (HAVE_FLAC 0)
endif ()
if (Opus_FOUND AND TARGET Opus::opus)
	set (HAVE_OPUS 1)
else ()
	set (HAVE_OPUS 0)
endif ()]=])
replace_text("${checks_file}" "${_old}" "${_new}")

set(cmake_file "${SNDFILE_SOURCE}/CMakeLists.txt")
set(_old [=[set (HAVE_EXTERNAL_XIPH_LIBS ${ENABLE_EXTERNAL_LIBS})]=])
replace_text("${cmake_file}" "${_old}" "")
set(_old [=[$<$<BOOL:${HAVE_EXTERNAL_XIPH_LIBS}>:FLAC::FLAC]=])
set(_new [=[$<$<BOOL:${HAVE_FLAC}>:FLAC::FLAC]=])
replace_text("${cmake_file}" "${_old}" "${_new}")
set(_old [=[$<$<BOOL:${HAVE_EXTERNAL_XIPH_LIBS}>:Opus::opus]=])
set(_new [=[$<$<BOOL:${HAVE_OPUS}>:Opus::opus]=])
replace_text("${cmake_file}" "${_old}" "${_new}")

set(config_file "${SNDFILE_SOURCE}/src/config.h.cmake")
set(_old [=[/* Will be set to 1 if flac, ogg and vorbis are available. */
#cmakedefine01 HAVE_EXTERNAL_XIPH_LIBS]=])
set(_new [=[/* Define to 1 if Ogg and Vorbis support is available. */
#cmakedefine01 HAVE_EXTERNAL_XIPH_LIBS

/* Define to 1 if FLAC support is available. */
#cmakedefine01 HAVE_FLAC

/* Define to 1 if Opus support is available. */
#cmakedefine01 HAVE_OPUS]=])
replace_text("${config_file}" "${_old}" "${_new}")

set(flac_file "${SNDFILE_SOURCE}/src/flac.c")
replace_text("${flac_file}" "#if HAVE_EXTERNAL_XIPH_LIBS" "#if HAVE_FLAC")
replace_text("${flac_file}" "#else /* HAVE_EXTERNAL_XIPH_LIBS */" "#else /* HAVE_FLAC */")

set(opus_file "${SNDFILE_SOURCE}/src/ogg_opus.c")
replace_text("${opus_file}" "#if HAVE_EXTERNAL_XIPH_LIBS" "#if HAVE_OPUS")
replace_text("${opus_file}" "#else /* HAVE_EXTERNAL_XIPH_LIBS */" "#else /* HAVE_OPUS */")

message(STATUS "Applied libsndfile Ogg/Vorbis-only compatibility patch")
