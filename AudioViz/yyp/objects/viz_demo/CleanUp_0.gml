if (global.aviz_file > 0) aviz_file_close(global.aviz_file);
if (global.aviz_record_buf != noone) buffer_delete(global.aviz_record_buf);
buffer_delete(global.aviz_samples);
buffer_delete(global.aviz_spectrum);
buffer_delete(global.aviz_spectrum_db);
buffer_delete(global.aviz_bands_target);
buffer_delete(global.aviz_bands);
aviz_waterfall_destroy(global.aviz_waterfall);
