#include <pspkernel.h>
#include <pspdebug.h>
#include <pspctrl.h>
#include <pspdisplay.h>
#include <pspge.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "fut15_data.h"

PSP_MODULE_INFO("UFT FUT15 Visual", 0, 0, 4);
PSP_MAIN_THREAD_ATTR(PSP_THREAD_ATTR_USER | PSP_THREAD_ATTR_VFPU);

#define FB_W 480
#define FB_H 272
#define FB_STRIDE 512
#define ASSET_COUNT 21

#define C_RGB(r,g,b) (0xFF000000u | ((unsigned int)(b)<<16) | ((unsigned int)(g)<<8) | (unsigned int)(r))
#define WHITE C_RGB(255,255,255)
#define BLACK C_RGB(0,0,0)
#define GREY C_RGB(175,185,190)
#define MUTED C_RGB(105,120,128)
#define ACCENT C_RGB(55,214,168)
#define YELLOW C_RGB(250,218,72)
#define PANEL C_RGB(18,26,33)
#define PANEL2 C_RGB(25,37,46)

typedef struct { int w,h; unsigned short *px; } Image16;
typedef struct { const char *name; const char *label; Image16 mini; Image16 full; } CardAsset;
typedef enum { SCR_HOME=0,SCR_PACK,SCR_DETAIL,SCR_DATABASE,SCR_TYPES } Screen;

static CardAsset assets[ASSET_COUNT]={
{"common_bronze","BRONZE COMMON",{0},{0}},{"common_gold","GOLD COMMON",{0},{0}},
{"common_silver","SILVER COMMON",{0},{0}},{"concept","CONCEPT",{0},{0}},
{"futties","FUTTIES",{0},{0}},{"heroes","HERO",{0},{0}},{"icon","LEGEND",{0},{0}},
{"motm","MOTM",{0},{0}},{"proplayer","PRO PLAYER",{0},{0}},{"rare_bronze","BRONZE RARE",{0},{0}},
{"rare_gold","GOLD RARE",{0},{0}},{"rare_silver","SILVER RARE",{0},{0}},
{"record_breaker","RECORD BREAKER",{0},{0}},{"st_patrick","ST PATRICK",{0},{0}},
{"tots_bronze","TOTS BRONZE",{0},{0}},{"tots_gold","TOTS GOLD",{0},{0}},
{"tots_silver","TOTS SILVER",{0},{0}},{"totw_bronze","TOTW BRONZE",{0},{0}},
{"totw_gold","TOTW GOLD",{0},{0}},{"totw_silver","TOTW SILVER",{0},{0}},{"toty","TOTY",{0},{0}}
};

static Screen screen=SCR_HOME,detailReturn=SCR_PACK;
static int homeMenu=0,packCards[6]={0},packSel=0,packModeLab=1,packsOpened=0,detailIndex=0,typesPage=0,dirty=1,missingAssets=0;
static unsigned char revealed[6]={0};
static unsigned int dbIndex=0;
static char baseDir[256]=".";

static int exit_callback(int a,int b,void*c){(void)a;(void)b;(void)c;sceKernelExitGame();return 0;}
static int callback_thread(SceSize a,void*b){(void)a;(void)b;int cb=sceKernelCreateCallback("Exit Callback",exit_callback,NULL);sceKernelRegisterExitCallback(cb);sceKernelSleepThreadCB();return 0;}
static void setup_callbacks(void){int th=sceKernelCreateThread("callback_thread",callback_thread,0x11,0xFA0,0,NULL);if(th>=0)sceKernelStartThread(th,0,NULL);}
static unsigned int *fb(void){return (unsigned int *)((uintptr_t)sceGeEdramGetAddr()|(uintptr_t)0x40000000u);}

static void fill_rect(int x,int y,int w,int h,unsigned int color){unsigned int*v=fb();int xx,yy;if(x<0){w+=x;x=0;}if(y<0){h+=y;y=0;}if(x+w>FB_W)w=FB_W-x;if(y+h>FB_H)h=FB_H-y;if(w<=0||h<=0)return;for(yy=0;yy<h;yy++){unsigned int*row=v+(y+yy)*FB_STRIDE+x;for(xx=0;xx<w;xx++)row[xx]=color;}}
static void border_rect(int x,int y,int w,int h,int t,unsigned int c){fill_rect(x,y,w,t,c);fill_rect(x,y+h-t,w,t,c);fill_rect(x,y,t,h,c);fill_rect(x+w-t,y,t,h,c);}
static void background(void){int y;for(y=0;y<FB_H;y++){int r=8+y*5/FB_H,g=15+y*13/FB_H,b=21+y*17/FB_H;fill_rect(0,y,FB_W,1,C_RGB(r,g,b));}fill_rect(0,0,FB_W,44,C_RGB(7,18,25));fill_rect(0,43,FB_W,1,C_RGB(40,65,76));fill_rect(0,244,FB_W,28,C_RGB(7,18,25));fill_rect(0,244,FB_W,1,C_RGB(40,65,76));}
static void text_px(int x,int y,unsigned int c,const char*s){pspDebugScreenSetBackColor(BLACK);pspDebugScreenEnableBackColor(0);while(*s){pspDebugScreenPutChar(x,y,c,(unsigned char)*s++);x+=8;}}
static void text_shadow(int x,int y,unsigned int c,const char*s){text_px(x+1,y+1,BLACK,s);text_px(x,y,c,s);}
static void text_trunc(int x,int y,unsigned int c,const char*s,int chars){char b[64];int n=(int)strlen(s);if(n>chars)n=chars;if(n>63)n=63;memcpy(b,s,n);b[n]=0;text_shadow(x,y,c,b);}
static void short_name(const char*src,char*dst,int max){int n=(int)strlen(src);const char*s=src;if(n>max){s=src+n-max;while(*s&&*s!=' ')s++;if(*s==' ')s++;if((int)strlen(s)>max)s=src+n-max;}snprintf(dst,max+1,"%s",s);}
static void set_base_dir(int argc,char**argv){const char*p;size_t n;if(argc<=0||!argv||!argv[0]||!argv[0][0])return;snprintf(baseDir,sizeof(baseDir),"%s",argv[0]);p=strrchr(baseDir,'/');if(!p)p=strrchr(baseDir,'\\');if(p){n=(size_t)(p-baseDir);baseDir[n]=0;}else snprintf(baseDir,sizeof(baseDir),".");}
static int load_c4(const char*path,Image16*im){FILE*f=fopen(path,"rb");unsigned short wh[2];size_t count;if(!f)return 0;if(fread(wh,2,2,f)!=2){fclose(f);return 0;}im->w=wh[0];im->h=wh[1];if(im->w<=0||im->h<=0||im->w>512||im->h>512){fclose(f);return 0;}count=(size_t)im->w*(size_t)im->h;im->px=(unsigned short*)malloc(count*2);if(!im->px){fclose(f);return 0;}if(fread(im->px,2,count,f)!=count){free(im->px);im->px=NULL;fclose(f);return 0;}fclose(f);return 1;}
static void load_assets(void){int i;char p[512];for(i=0;i<ASSET_COUNT;i++){snprintf(p,sizeof(p),"%s/assets/cards/mini/%s.c4",baseDir,assets[i].name);if(!load_c4(p,&assets[i].mini))missingAssets++;snprintf(p,sizeof(p),"%s/assets/cards/full/%s.c4",baseDir,assets[i].name);if(!load_c4(p,&assets[i].full))missingAssets++;}}
static void draw_image(int x,int y,const Image16*im){unsigned int*v=fb();int xx,yy;if(!im||!im->px)return;for(yy=0;yy<im->h;yy++){int dy=y+yy;if(dy<0||dy>=FB_H)continue;for(xx=0;xx<im->w;xx++){int dx=x+xx;unsigned short p;int r,g,b,a;unsigned int d;int dr,dg,db;if(dx<0||dx>=FB_W)continue;p=im->px[yy*im->w+xx];a=((p>>12)&15)*17;if(a==0)continue;r=(p&15)*17;g=((p>>4)&15)*17;b=((p>>8)&15)*17;if(a>=250)v[dy*FB_STRIDE+dx]=C_RGB(r,g,b);else{d=v[dy*FB_STRIDE+dx];dr=d&255;dg=(d>>8)&255;db=(d>>16)&255;r=(r*a+dr*(255-a))/255;g=(g*a+dg*(255-a))/255;b=(b*a+db*(255-a))/255;v[dy*FB_STRIDE+dx]=C_RGB(r,g,b);}}}}
static CardAsset*asset_named(const char*n){int i;for(i=0;i<ASSET_COUNT;i++)if(!strcmp(assets[i].name,n))return &assets[i];return &assets[10];}
static int base_tier(const Fut15Card*c){if(c->rating>=75)return 2;if(c->rating>=65)return 1;return 0;}
static CardAsset*asset_for(const Fut15Card*c){const char*v=c->version;int t=base_tier(c);if(!strcmp(v,"TOTY"))return asset_named("toty");if(!strcmp(v,"TOTS"))return asset_named(t==2?"tots_gold":(t==1?"tots_silver":"tots_bronze"));if(!strcmp(v,"IF"))return asset_named(t==2?"totw_gold":(t==1?"totw_silver":"totw_bronze"));if(!strcmp(v,"MOTM"))return asset_named("motm");if(!strcmp(v,"RB"))return asset_named("record_breaker");if(!strcmp(v,"Futties"))return asset_named("futties");if(!strcmp(v,"Legend"))return asset_named("icon");if(!strcmp(v,"POTY")||strstr(v,"Hero")||strstr(v,"HERO"))return asset_named("heroes");if(strstr(v,"Patrick")||strstr(v,"PATRICK"))return asset_named("st_patrick");if(strstr(v,"Pro")||strstr(v,"PRO"))return asset_named("proplayer");if(!strcmp(v,"Gold_Non-rare"))return asset_named("common_gold");if(!strcmp(v,"Gold"))return asset_named("rare_gold");if(!strcmp(v,"Silver"))return asset_named(c->rating>=70?"rare_silver":"common_silver");if(!strcmp(v,"Bronze"))return asset_named(c->rating>=63?"rare_bronze":"common_bronze");return asset_named("concept");}
static int is_base_version(const char*v){return !strcmp(v,"Gold")||!strcmp(v,"Silver")||!strcmp(v,"Bronze")||!strcmp(v,"Gold_Non-rare");}
static int is_special(const Fut15Card*c){return !is_base_version(c->version);}
static void header(const char*s){char b[128];background();text_shadow(16,12,ACCENT,"UFT 15 PORTABLE");text_shadow(164,12,WHITE,s);snprintf(b,sizeof(b),"FUT15 DB %u | %u clubs | %u special",fut15_card_count,fut15_club_count,fut15_special_count);text_shadow(16,29,MUTED,b);}
static void footer(const char*s){text_shadow(16,253,GREY,s);}
static void card_text_mini(int x,int y,const Fut15Card*c){char b[24],sn[16];snprintf(b,sizeof(b),"%d",c->rating);text_shadow(x+8,y+10,BLACK,b);text_shadow(x+8,y+23,BLACK,c->position);short_name(c->name,sn,8);text_shadow(x+4,y+68,BLACK,sn);}
static void card_text_full(int x,int y,const Fut15Card*c){char b[64],sn[24];snprintf(b,sizeof(b),"%d",c->rating);text_shadow(x+18,y+22,BLACK,b);text_shadow(x+18,y+39,BLACK,c->position);short_name(c->name,sn,16);text_shadow(x+12,y+132,BLACK,sn);snprintf(b,sizeof(b),"%02d PAC %02d DRI",c->pac,c->dri);text_shadow(x+13,y+158,BLACK,b);snprintf(b,sizeof(b),"%02d SHO %02d DEF",c->sho,c->def);text_shadow(x+13,y+175,BLACK,b);snprintf(b,sizeof(b),"%02d PAS %02d PHY",c->pas,c->phy);text_shadow(x+13,y+192,BLACK,b);}
static int same_player_in_pack(int upto,int idx){int i;for(i=0;i<upto;i++)if(!strcmp(fut15_cards[packCards[i]].name,fut15_cards[idx].name))return 1;return 0;}
static int pick_by_type(int want){int tries=0,idx=0;do{idx=rand()%(int)fut15_card_count;tries++;if(!!is_special(&fut15_cards[idx])==!!want)return idx;}while(tries<30000);return idx;}
static void open_pack(int lab){int i;packsOpened++;packModeLab=lab;packSel=0;for(i=0;i<6;i++){int idx,tries=0;int sr=lab?((rand()%100)<35):((rand()%1000)<12);do{idx=pick_by_type(sr);tries++;}while(same_player_in_pack(i,idx)&&tries<100);packCards[i]=idx;revealed[i]=0;}screen=SCR_PACK;dirty=1;}

static void draw_home(void){static const char*items[]={"ABRIR SOBRE LAB","ABRIR SOBRE NORMAL","BASE DE DATOS FUT 15","GALERIA DE CARTAS","SALIR"};int i;char b[96];CardAsset*a1=asset_named("rare_gold"),*a2=asset_named("totw_gold"),*a3=asset_named("toty");header("ULTIMATE TEAM / CARD LAB");fill_rect(18,60,245,166,PANEL);border_rect(18,60,245,166,1,C_RGB(45,67,79));text_shadow(34,75,WHITE,"FIFA 15 PACK OPENER");snprintf(b,sizeof(b),"%d sobres abiertos",packsOpened);text_shadow(34,94,MUTED,b);for(i=0;i<5;i++){int y=122+i*20;if(homeMenu==i){fill_rect(31,y-5,218,18,C_RGB(31,76,80));fill_rect(31,y-5,4,18,ACCENT);}text_shadow(42,y,homeMenu==i?WHITE:GREY,items[i]);}if(a1->mini.px)draw_image(288,104,&a1->mini);if(a2->mini.px)draw_image(332,84,&a2->mini);if(a3->mini.px)draw_image(376,64,&a3->mini);text_shadow(290,194,MUTED,"21 DISENOS CARGADOS");if(missingAssets){snprintf(b,sizeof(b),"AVISO: %d assets no cargados",missingAssets);text_shadow(290,212,YELLOW,b);}footer("D-Pad mover [X] aceptar START salir");}
static void draw_pack(void){int i;char b[128];header(packModeLab?"SOBRE LAB / ALTA PROBABILIDAD":"SOBRE NORMAL");snprintf(b,sizeof(b),"SOBRE #%d     %s",packsOpened,packModeLab?"35% especial por carta":"probabilidad normal de prueba");text_shadow(16,52,MUTED,b);for(i=0;i<6;i++){int x=10+i*78,y=76;if(i==packSel)border_rect(x-4,y-4,78,96,3,YELLOW);if(!revealed[i]){CardAsset*back=asset_named("concept");draw_image(x,y,&back->mini);text_shadow(x+22,y+34,WHITE,"???");}else{const Fut15Card*c=&fut15_cards[packCards[i]];CardAsset*a=asset_for(c);draw_image(x,y,&a->mini);card_text_mini(x,y,c);}}fill_rect(16,180,448,50,PANEL2);if(revealed[packSel]){const Fut15Card*c=&fut15_cards[packCards[packSel]];CardAsset*a=asset_for(c);snprintf(b,sizeof(b),"%d %s  %s",c->rating,c->position,c->name);text_shadow(28,190,WHITE,b);snprintf(b,sizeof(b),"%s | %s | %s",c->club,c->version,a->label);text_shadow(28,209,GREY,b);}else{text_shadow(28,194,WHITE,"Pulsa X para revelar la carta seleccionada");text_shadow(28,211,MUTED,"TRIANGULO revela las seis");}footer("IZQ/DER seleccionar [X] revelar/abrir TRIANGULO todas [O] menu");}
static void draw_detail_card(const Fut15Card*c,const char*s){char b[128];CardAsset*a=asset_for(c);header(s);draw_image(24,49,&a->full);card_text_full(24,49,c);fill_rect(198,58,264,172,PANEL);border_rect(198,58,264,172,1,C_RGB(45,67,79));snprintf(b,sizeof(b),"%d %s",c->rating,c->position);text_shadow(216,76,YELLOW,b);text_trunc(216,98,WHITE,c->name,28);text_trunc(216,118,GREY,c->club,28);text_trunc(216,136,MUTED,c->league,28);snprintf(b,sizeof(b),"TIPO: %s",a->label);text_shadow(216,159,ACCENT,b);snprintf(b,sizeof(b),"VERSION DB: %s",c->version);text_shadow(216,177,GREY,b);snprintf(b,sizeof(b),"%02d PAC %02d SHO %02d PAS",c->pac,c->sho,c->pas);text_shadow(216,201,WHITE,b);snprintf(b,sizeof(b),"%02d DRI %02d DEF %02d PHY",c->dri,c->def,c->phy);text_shadow(216,218,WHITE,b);}
static void draw_detail(void){draw_detail_card(&fut15_cards[detailIndex],"DETALLE DE CARTA");footer("IZQ/DER otra carta del sobre [O] volver");}
static void draw_database(void){char b[96];detailIndex=(int)dbIndex;draw_detail_card(&fut15_cards[dbIndex],"NAVEGADOR FUT 15");snprintf(b,sizeof(b),"REGISTRO %u / %u",dbIndex+1,fut15_card_count);text_shadow(344,29,MUTED,b);footer("IZQ/DER +/-1 ARR/ABA +/-50 TRIANGULO aleatoria [O] menu");}
static void draw_types(void){int start=typesPage*8,i;char b[64];header("GALERIA DE TIPOS DE CARTA");snprintf(b,sizeof(b),"Pagina %d / 3",typesPage+1);text_shadow(388,29,MUTED,b);for(i=0;i<8;i++){int idx=start+i,col=i%4,row=i/4,x=34+col*112,y=59+row*93;if(idx>=ASSET_COUNT)break;draw_image(x,y,&assets[idx].mini);text_trunc(x-8,y+72,WHITE,assets[idx].label,11);}footer("IZQ/DER cambiar pagina [O] volver");}
static unsigned int pressed(unsigned int n,unsigned int o,unsigned int m){return(n&m)&&!(o&m);}
static void render(void){if(screen==SCR_HOME)draw_home();else if(screen==SCR_PACK)draw_pack();else if(screen==SCR_DETAIL)draw_detail();else if(screen==SCR_DATABASE)draw_database();else draw_types();dirty=0;}

int main(int argc,char*argv[]){SceCtrlData pad;unsigned int old=0;setup_callbacks();pspDebugScreenInit();pspDebugScreenEnableBackColor(0);sceCtrlSetSamplingCycle(0);sceCtrlSetSamplingMode(PSP_CTRL_MODE_ANALOG);set_base_dir(argc,argv);load_assets();srand((unsigned int)sceKernelGetSystemTimeLow());while(1){sceCtrlPeekBufferPositive(&pad,1);if(pressed(pad.Buttons,old,PSP_CTRL_START))sceKernelExitGame();if(screen==SCR_HOME){if(pressed(pad.Buttons,old,PSP_CTRL_UP)){homeMenu=(homeMenu+4)%5;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_DOWN)){homeMenu=(homeMenu+1)%5;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_CROSS)){if(homeMenu==0)open_pack(1);else if(homeMenu==1)open_pack(0);else if(homeMenu==2){dbIndex=0;screen=SCR_DATABASE;dirty=1;}else if(homeMenu==3){typesPage=0;screen=SCR_TYPES;dirty=1;}else sceKernelExitGame();}}else if(screen==SCR_PACK){if(pressed(pad.Buttons,old,PSP_CTRL_LEFT)){packSel=(packSel+5)%6;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_RIGHT)){packSel=(packSel+1)%6;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_TRIANGLE)){int i;for(i=0;i<6;i++)revealed[i]=1;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_CROSS)){if(!revealed[packSel]){revealed[packSel]=1;dirty=1;}else{detailIndex=packCards[packSel];detailReturn=SCR_PACK;screen=SCR_DETAIL;dirty=1;}}if(pressed(pad.Buttons,old,PSP_CTRL_CIRCLE)){screen=SCR_HOME;dirty=1;}}else if(screen==SCR_DETAIL){if(pressed(pad.Buttons,old,PSP_CTRL_LEFT)){packSel=(packSel+5)%6;revealed[packSel]=1;detailIndex=packCards[packSel];dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_RIGHT)){packSel=(packSel+1)%6;revealed[packSel]=1;detailIndex=packCards[packSel];dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_CIRCLE)){screen=detailReturn;dirty=1;}}else if(screen==SCR_DATABASE){if(pressed(pad.Buttons,old,PSP_CTRL_LEFT)){dbIndex=(dbIndex==0?fut15_card_count-1:dbIndex-1);dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_RIGHT)){dbIndex=(dbIndex+1)%fut15_card_count;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_UP)){dbIndex=(dbIndex+fut15_card_count-(50%fut15_card_count))%fut15_card_count;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_DOWN)){dbIndex=(dbIndex+50)%fut15_card_count;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_TRIANGLE)){dbIndex=rand()%(int)fut15_card_count;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_CIRCLE)){screen=SCR_HOME;dirty=1;}}else if(screen==SCR_TYPES){if(pressed(pad.Buttons,old,PSP_CTRL_LEFT)){typesPage=(typesPage+2)%3;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_RIGHT)){typesPage=(typesPage+1)%3;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_CIRCLE)){screen=SCR_HOME;dirty=1;}}if(dirty)render();old=pad.Buttons;sceDisplayWaitVblankStart();}return 0;}
