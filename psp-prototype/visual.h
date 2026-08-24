#ifndef UFT_VISUAL_H
#define UFT_VISUAL_H

#include "fut15_data.h"

#define UFT_FB_W 480
#define UFT_FB_H 272

#define UFT_RGB(r,g,b) (0xFF000000u | ((unsigned int)(b)<<16) | ((unsigned int)(g)<<8) | (unsigned int)(r))
#define UFT_WHITE UFT_RGB(255,255,255)
#define UFT_BLACK UFT_RGB(0,0,0)
#define UFT_GREY UFT_RGB(181,191,197)
#define UFT_MUTED UFT_RGB(108,126,137)
#define UFT_ACCENT UFT_RGB(61,219,170)
#define UFT_YELLOW UFT_RGB(250,218,72)
#define UFT_PANEL UFT_RGB(17,28,36)
#define UFT_PANEL2 UFT_RGB(24,39,49)

enum {
    UFT_FONT_EB12=0,
    UFT_FONT_EB15,
    UFT_FONT_EB16,
    UFT_FONT_EB24,
    UFT_FONT_R9,
    UFT_FONT_R12,
    UFT_FONT_R15
};

void visual_init(const char *base_dir);
void visual_background(void);
void visual_fill_rect(int x,int y,int w,int h,unsigned int color);
void visual_border_rect(int x,int y,int w,int h,int t,unsigned int color);
void visual_text(int font_id,int x,int y,unsigned int color,const char *text);
void visual_text_shadow(int font_id,int x,int y,unsigned int color,const char *text);
void visual_text_center(int font_id,int center_x,int y,unsigned int color,const char *text);
int visual_text_width(int font_id,const char *text);
void visual_header(const char *section);
void visual_footer(const char *text);
void visual_draw_card_mini(int x,int y,const Fut15Card *card,int hidden);
void visual_draw_card_full(int x,int y,const Fut15Card *card);
void visual_draw_type_preview(int type_index,int x,int y);
int visual_type_count(void);
const char *visual_card_type_label(const Fut15Card *card);
int visual_missing_assets(void);
int visual_missing_fonts(void);

#endif
