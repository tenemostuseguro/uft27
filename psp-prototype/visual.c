#include <pspge.h>
#include <pspdebug.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "visual.h"

#define FB_STRIDE 512
#define ASSET_COUNT 21
#define FONT_COUNT 7
#define CARD_DARK UFT_RGB(45,48,51)
#define DIVIDER UFT_RGB(139,128,119)

typedef struct { int w,h; unsigned short *px; } Image16;
typedef struct { const char *name; const char *label; Image16 mini; Image16 full; } CardAsset;
typedef struct { unsigned short code,x,y,w,h; short xoff,yoff,advance; } Glyph;
typedef struct { const char *file; int w,h,count,line_height,ascent; Glyph *glyphs; unsigned char *alpha; } FontAtlas;

static CardAsset assets[ASSET_COUNT]={
    {"common_bronze","BRONZE COMMON",{0},{0}}, {"common_gold","GOLD COMMON",{0},{0}},
    {"common_silver","SILVER COMMON",{0},{0}}, {"concept","CONCEPT",{0},{0}},
    {"futties","FUTTIES",{0},{0}}, {"heroes","HERO",{0},{0}}, {"icon","LEGEND",{0},{0}},
    {"motm","MOTM",{0},{0}}, {"proplayer","PRO PLAYER",{0},{0}}, {"rare_bronze","BRONZE RARE",{0},{0}},
    {"rare_gold","GOLD RARE",{0},{0}}, {"rare_silver","SILVER RARE",{0},{0}},
    {"record_breaker","RECORD BREAKER",{0},{0}}, {"st_patrick","ST PATRICK",{0},{0}},
    {"tots_bronze","TOTS BRONZE",{0},{0}}, {"tots_gold","TOTS GOLD",{0},{0}},
    {"tots_silver","TOTS SILVER",{0},{0}}, {"totw_bronze","TOTW BRONZE",{0},{0}},
    {"totw_gold","TOTW GOLD",{0},{0}}, {"totw_silver","TOTW SILVER",{0},{0}}, {"toty","TOTY",{0},{0}}
};

static FontAtlas fonts[FONT_COUNT]={
    {"knul_eb12.kfa",0,0,0,0,0,NULL,NULL}, {"knul_eb15.kfa",0,0,0,0,0,NULL,NULL},
    {"knul_eb16.kfa",0,0,0,0,0,NULL,NULL}, {"knul_eb24.kfa",0,0,0,0,0,NULL,NULL},
    {"knul_reg9.kfa",0,0,0,0,0,NULL,NULL}, {"knul_reg12.kfa",0,0,0,0,0,NULL,NULL},
    {"knul_reg15.kfa",0,0,0,0,0,NULL,NULL}
};

static Image16 face_mini={0},face_full={0};
static int missing_assets=0,missing_fonts=0;
static char base_dir[256]=".";

static unsigned int *fb(void){ return (unsigned int *)((uintptr_t)sceGeEdramGetAddr()|(uintptr_t)0x40000000u); }
static unsigned int mix_color(unsigned int dst,unsigned int src,int alpha){
    int dr=dst&255,dg=(dst>>8)&255,db=(dst>>16)&255;
    int sr=src&255,sg=(src>>8)&255,sb=(src>>16)&255;
    return UFT_RGB((sr*alpha+dr*(255-alpha))/255,(sg*alpha+dg*(255-alpha))/255,(sb*alpha+db*(255-alpha))/255);
}

void visual_fill_rect(int x,int y,int w,int h,unsigned int color){
    unsigned int *v=fb(); int xx,yy;
    if(x<0){w+=x;x=0;} if(y<0){h+=y;y=0;}
    if(x+w>UFT_FB_W)w=UFT_FB_W-x; if(y+h>UFT_FB_H)h=UFT_FB_H-y;
    if(w<=0||h<=0)return;
    for(yy=0;yy<h;yy++){ unsigned int *row=v+(y+yy)*FB_STRIDE+x; for(xx=0;xx<w;xx++)row[xx]=color; }
}
void visual_border_rect(int x,int y,int w,int h,int t,unsigned int c){
    visual_fill_rect(x,y,w,t,c);visual_fill_rect(x,y+h-t,w,t,c);visual_fill_rect(x,y,t,h,c);visual_fill_rect(x+w-t,y,t,h,c);
}
void visual_background(void){
    int y; for(y=0;y<UFT_FB_H;y++)visual_fill_rect(0,y,UFT_FB_W,1,UFT_RGB(7+y*5/UFT_FB_H,15+y*15/UFT_FB_H,21+y*20/UFT_FB_H));
    visual_fill_rect(0,0,UFT_FB_W,43,UFT_RGB(7,18,25)); visual_fill_rect(0,42,UFT_FB_W,1,UFT_RGB(39,62,73));
}

static int load_c4(const char *path,Image16 *im){
    FILE *f=fopen(path,"rb"); unsigned short wh[2]; size_t count;
    if(!f)return 0; if(fread(wh,2,2,f)!=2){fclose(f);return 0;}
    im->w=wh[0]; im->h=wh[1]; if(im->w<=0||im->h<=0||im->w>512||im->h>512){fclose(f);return 0;}
    count=(size_t)im->w*(size_t)im->h; im->px=(unsigned short*)malloc(count*2); if(!im->px){fclose(f);return 0;}
    if(fread(im->px,2,count,f)!=count){free(im->px);im->px=NULL;fclose(f);return 0;} fclose(f); return 1;
}

static void draw_image(int x,int y,const Image16 *im){
    unsigned int *v=fb(); int xx,yy; if(!im||!im->px)return;
    for(yy=0;yy<im->h;yy++){ int dy=y+yy; if(dy<0||dy>=UFT_FB_H)continue;
        for(xx=0;xx<im->w;xx++){ int dx=x+xx,r,g,b,a; unsigned short p; unsigned int d; if(dx<0||dx>=UFT_FB_W)continue;
            p=im->px[yy*im->w+xx]; a=((p>>12)&15)*17; if(!a)continue; r=(p&15)*17;g=((p>>4)&15)*17;b=((p>>8)&15)*17;
            if(a>=250)v[dy*FB_STRIDE+dx]=UFT_RGB(r,g,b); else{d=v[dy*FB_STRIDE+dx];v[dy*FB_STRIDE+dx]=mix_color(d,UFT_RGB(r,g,b),a);} }
    }
}

static int load_font(const char *path,FontAtlas *f){
    FILE *fp=fopen(path,"rb"); char magic[4]; unsigned short u16; short s16; int i;
    if(!fp)return 0; if(fread(magic,1,4,fp)!=4||memcmp(magic,"KFA1",4)){fclose(fp);return 0;}
    if(fread(&u16,2,1,fp)!=1){fclose(fp);return 0;}f->w=u16; fread(&u16,2,1,fp);f->h=u16; fread(&u16,2,1,fp);f->count=u16;
    fread(&u16,2,1,fp);f->line_height=u16; fread(&s16,2,1,fp);f->ascent=s16;
    if(f->w<=0||f->h<=0||f->count<=0||f->count>256){fclose(fp);return 0;}
    f->glyphs=(Glyph*)malloc(sizeof(Glyph)*f->count); if(!f->glyphs){fclose(fp);return 0;}
    for(i=0;i<f->count;i++){ Glyph *g=&f->glyphs[i]; fread(&g->code,2,1,fp);fread(&g->x,2,1,fp);fread(&g->y,2,1,fp);fread(&g->w,2,1,fp);fread(&g->h,2,1,fp);fread(&g->xoff,2,1,fp);fread(&g->yoff,2,1,fp);fread(&g->advance,2,1,fp); }
    f->alpha=(unsigned char*)malloc((size_t)f->w*(size_t)f->h); if(!f->alpha){free(f->glyphs);f->glyphs=NULL;fclose(fp);return 0;}
    if(fread(f->alpha,1,(size_t)f->w*(size_t)f->h,fp)!=(size_t)f->w*(size_t)f->h){free(f->glyphs);free(f->alpha);f->glyphs=NULL;f->alpha=NULL;fclose(fp);return 0;}
    fclose(fp);return 1;
}

static Glyph *glyph_for(FontAtlas *f,unsigned char c){ int i;if(!f||!f->glyphs)return NULL;for(i=0;i<f->count;i++)if(f->glyphs[i].code==c)return &f->glyphs[i];return NULL; }
static void draw_glyph(FontAtlas *f,Glyph *g,int penx,int baseline,unsigned int color){
    unsigned int *v=fb();int xx,yy;if(!f||!g||!f->alpha||!g->w||!g->h)return;
    for(yy=0;yy<g->h;yy++){int dy=baseline+g->yoff+yy;if(dy<0||dy>=UFT_FB_H)continue;
        for(xx=0;xx<g->w;xx++){int dx=penx+g->xoff+xx,a;unsigned int *p;if(dx<0||dx>=UFT_FB_W)continue;a=f->alpha[(g->y+yy)*f->w+(g->x+xx)];if(!a)continue;p=&v[dy*FB_STRIDE+dx];*p=mix_color(*p,color,a);}}
}
int visual_text_width(int font_id,const char *s){int w=0;Glyph*g;FontAtlas*f=&fonts[font_id];while(s&&*s){g=glyph_for(f,(unsigned char)*s++);if(g)w+=g->advance;}return w;}
void visual_text(int font_id,int x,int top,unsigned int color,const char *s){FontAtlas*f=&fonts[font_id];int baseline=f->ascent+top;Glyph*g;while(s&&*s){g=glyph_for(f,(unsigned char)*s++);if(g){draw_glyph(f,g,x,baseline,color);x+=g->advance;}}}
void visual_text_shadow(int font_id,int x,int y,unsigned int color,const char *s){visual_text(font_id,x+1,y+1,UFT_BLACK,s);visual_text(font_id,x,y,color,s);}
void visual_text_center(int font_id,int cx,int y,unsigned int color,const char *s){visual_text(font_id,cx-visual_text_width(font_id,s)/2,y,color,s);}

static CardAsset *asset_named(const char *n){int i;for(i=0;i<ASSET_COUNT;i++)if(!strcmp(assets[i].name,n))return &assets[i];return &assets[10];}
static int base_tier(const Fut15Card*c){if(c->rating>=75)return 2;if(c->rating>=65)return 1;return 0;}
static CardAsset *asset_for(const Fut15Card*c){
    const char*v=c->version;int t=base_tier(c);
    if(!strcmp(v,"TOTY"))return asset_named("toty"); if(!strcmp(v,"TOTS"))return asset_named(t==2?"tots_gold":(t==1?"tots_silver":"tots_bronze"));
    if(!strcmp(v,"IF"))return asset_named(t==2?"totw_gold":(t==1?"totw_silver":"totw_bronze")); if(!strcmp(v,"MOTM"))return asset_named("motm");
    if(!strcmp(v,"RB"))return asset_named("record_breaker"); if(!strcmp(v,"Futties"))return asset_named("futties"); if(!strcmp(v,"Legend"))return asset_named("icon");
    if(!strcmp(v,"POTY")||strstr(v,"Hero")||strstr(v,"HERO"))return asset_named("heroes"); if(strstr(v,"Patrick")||strstr(v,"PATRICK"))return asset_named("st_patrick");
    if(strstr(v,"Pro")||strstr(v,"PRO"))return asset_named("proplayer"); if(!strcmp(v,"Gold_Non-rare"))return asset_named("common_gold"); if(!strcmp(v,"Gold"))return asset_named("rare_gold");
    if(!strcmp(v,"Silver"))return asset_named(c->rating>=70?"rare_silver":"common_silver"); if(!strcmp(v,"Bronze"))return asset_named(c->rating>=63?"rare_bronze":"common_bronze"); return asset_named("concept");
}
static unsigned int card_text_color(CardAsset*a){
    if(!a)return CARD_DARK;
    if(!strcmp(a->name,"toty")||!strncmp(a->name,"tots_",5)||!strncmp(a->name,"totw_",5)||!strcmp(a->name,"motm")||!strcmp(a->name,"record_breaker")||!strcmp(a->name,"futties")||!strcmp(a->name,"heroes")||!strcmp(a->name,"proplayer")||!strcmp(a->name,"st_patrick"))return UFT_WHITE;
    return CARD_DARK;
}
static void uppercase_copy(const char*src,char*dst,int cap){int i=0;while(*src&&i<cap-1){char c=*src++;if(c>='a'&&c<='z')c=(char)(c-'a'+'A');dst[i++]=c;}dst[i]=0;}

void visual_draw_card_mini(int x,int y,const Fut15Card*c,int hidden){
    CardAsset*a=hidden?asset_named("concept"):asset_for(c);unsigned int tc=hidden?UFT_WHITE:card_text_color(a);char b[16];
    draw_image(x,y,&a->mini); if(hidden){visual_text_center(UFT_FONT_EB16,x+35,y+30,UFT_WHITE,"?");return;}
    draw_image(x+23,y+20,&face_mini); snprintf(b,sizeof(b),"%d",c->rating);visual_text(UFT_FONT_EB12,x+9,y+12,tc,b);
    visual_fill_rect(x+26,y+10,1,13,mix_color(tc,DIVIDER,110));visual_text(UFT_FONT_R9,x+32,y+13,tc,c->position);
}
void visual_draw_card_full(int x,int y,const Fut15Card*c){
    CardAsset*a=asset_for(c);unsigned int tc=card_text_color(a);char b[64],name[64];int nf=UFT_FONT_EB16;
    draw_image(x,y,&a->full);draw_image(x+59,y+41,&face_full);uppercase_copy(c->name,name,sizeof(name));
    if(visual_text_width(nf,name)>138)nf=UFT_FONT_EB15;if(visual_text_width(nf,name)>138)nf=UFT_FONT_EB12;visual_text_center(nf,x+75,y+17,tc,name);
    snprintf(b,sizeof(b),"%d",c->rating);visual_text(UFT_FONT_EB24,x+18,y+36,tc,b);visual_fill_rect(x+49,y+36,1,18,mix_color(tc,DIVIDER,110));visual_text(UFT_FONT_R15,x+58,y+40,tc,c->position);
    snprintf(b,sizeof(b),"%d",c->pac);visual_text(UFT_FONT_EB15,x+24,y+152,tc,b);visual_text(UFT_FONT_R15,x+46,y+152,tc,"PAC");
    snprintf(b,sizeof(b),"%d",c->dri);visual_text(UFT_FONT_EB15,x+82,y+152,tc,b);visual_text(UFT_FONT_R15,x+103,y+152,tc,"DRI");
    snprintf(b,sizeof(b),"%d",c->sho);visual_text(UFT_FONT_EB15,x+24,y+173,tc,b);visual_text(UFT_FONT_R15,x+46,y+173,tc,"SHO");
    snprintf(b,sizeof(b),"%d",c->def);visual_text(UFT_FONT_EB15,x+82,y+173,tc,b);visual_text(UFT_FONT_R15,x+103,y+173,tc,"DEF");
    snprintf(b,sizeof(b),"%d",c->pas);visual_text(UFT_FONT_EB15,x+24,y+193,tc,b);visual_text(UFT_FONT_R15,x+46,y+193,tc,"PAS");
    snprintf(b,sizeof(b),"%d",c->phy);visual_text(UFT_FONT_EB15,x+82,y+193,tc,b);visual_text(UFT_FONT_R15,x+103,y+193,tc,"PHY");
}

void visual_header(const char *section){char b[128];visual_background();visual_text_shadow(UFT_FONT_EB16,16,10,UFT_ACCENT,"UFT 15");visual_text_shadow(UFT_FONT_R12,84,13,UFT_WHITE,section);snprintf(b,sizeof(b),"%u CARDS  /  %u CLUBS  /  %u SPECIAL",fut15_card_count,fut15_club_count,fut15_special_count);visual_text(UFT_FONT_R9,16,31,UFT_MUTED,b);}
void visual_footer(const char *text){visual_fill_rect(0,246,UFT_FB_W,26,UFT_RGB(7,18,25));visual_text(UFT_FONT_R9,16,253,UFT_GREY,text);}
void visual_draw_type_preview(int idx,int x,int y){if(idx<0||idx>=ASSET_COUNT)return;draw_image(x,y,&assets[idx].mini);draw_image(x+23,y+20,&face_mini);visual_text_center(UFT_FONT_R9,x+35,y+73,UFT_WHITE,assets[idx].label);}
int visual_type_count(void){return ASSET_COUNT;}
const char *visual_card_type_label(const Fut15Card *card){return asset_for(card)->label;}
int visual_missing_assets(void){return missing_assets;}
int visual_missing_fonts(void){return missing_fonts;}

void visual_init(const char *dir){
    int i;char p[512];snprintf(base_dir,sizeof(base_dir),"%s",dir&&dir[0]?dir:".");pspDebugScreenInit();pspDebugScreenEnableBackColor(0);
    for(i=0;i<ASSET_COUNT;i++){snprintf(p,sizeof(p),"%s/assets/cards/mini/%s.c4",base_dir,assets[i].name);if(!load_c4(p,&assets[i].mini))missing_assets++;snprintf(p,sizeof(p),"%s/assets/cards/full/%s.c4",base_dir,assets[i].name);if(!load_c4(p,&assets[i].full))missing_assets++;}
    snprintf(p,sizeof(p),"%s/assets/faces/placeholder_mini.c4",base_dir);if(!load_c4(p,&face_mini))missing_assets++;
    snprintf(p,sizeof(p),"%s/assets/faces/placeholder_full.c4",base_dir);if(!load_c4(p,&face_full))missing_assets++;
    for(i=0;i<FONT_COUNT;i++){snprintf(p,sizeof(p),"%s/assets/fonts/%s",base_dir,fonts[i].file);if(!load_font(p,&fonts[i]))missing_fonts++;}
}
