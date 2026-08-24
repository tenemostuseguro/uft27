#include <pspkernel.h>
#include <pspctrl.h>
#include <pspdisplay.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "fut15_data.h"
#include "visual.h"

PSP_MODULE_INFO("UFT FUT15 Visual", 0, 0, 5);
PSP_MAIN_THREAD_ATTR(PSP_THREAD_ATTR_USER | PSP_THREAD_ATTR_VFPU);

typedef enum { SCR_HOME=0,SCR_PACK,SCR_DETAIL,SCR_DATABASE,SCR_TYPES } Screen;
static Screen screen=SCR_HOME,detail_return=SCR_PACK;
static int home_menu=0,pack_cards[6]={0},pack_sel=0,pack_lab=1,packs_opened=0,detail_index=0,types_page=0,dirty=1;
static unsigned char revealed[6]={0};
static unsigned int db_index=0;
static char base_dir[256]=".";

static int exit_callback(int a,int b,void*c){(void)a;(void)b;(void)c;sceKernelExitGame();return 0;}
static int callback_thread(SceSize a,void*b){(void)a;(void)b;int cb=sceKernelCreateCallback("Exit Callback",exit_callback,NULL);sceKernelRegisterExitCallback(cb);sceKernelSleepThreadCB();return 0;}
static void setup_callbacks(void){int th=sceKernelCreateThread("callback_thread",callback_thread,0x11,0xFA0,0,NULL);if(th>=0)sceKernelStartThread(th,0,NULL);}
static void set_base_dir(int argc,char**argv){const char*p;size_t n;if(argc<=0||!argv||!argv[0]||!argv[0][0])return;snprintf(base_dir,sizeof(base_dir),"%s",argv[0]);p=strrchr(base_dir,'/');if(!p)p=strrchr(base_dir,'\\');if(p){n=(size_t)(p-base_dir);base_dir[n]=0;}else snprintf(base_dir,sizeof(base_dir),".");}
static int is_base_version(const char*v){return !strcmp(v,"Gold")||!strcmp(v,"Silver")||!strcmp(v,"Bronze")||!strcmp(v,"Gold_Non-rare");}
static int is_special(const Fut15Card*c){return !is_base_version(c->version);}
static int same_player(int upto,int idx){int i;for(i=0;i<upto;i++)if(!strcmp(fut15_cards[pack_cards[i]].name,fut15_cards[idx].name))return 1;return 0;}
static int pick_by_type(int special){int tries=0,idx=0;do{idx=rand()%(int)fut15_card_count;tries++;if(!!is_special(&fut15_cards[idx])==!!special)return idx;}while(tries<30000);return idx;}
static void open_pack(int lab){int i;packs_opened++;pack_lab=lab;pack_sel=0;for(i=0;i<6;i++){int idx,tries=0,special=lab?((rand()%100)<35):((rand()%1000)<12);do{idx=pick_by_type(special);tries++;}while(same_player(i,idx)&&tries<100);pack_cards[i]=idx;revealed[i]=0;}screen=SCR_PACK;dirty=1;}

static void draw_home(void){
    static const char*items[]={"ABRIR SOBRE LAB","ABRIR SOBRE NORMAL","BASE DE DATOS FUT 15","GALERIA DE CARTAS","SALIR"};int i;char b[96];
    visual_header("ULTIMATE TEAM / CARD LAB");visual_fill_rect(18,58,250,174,UFT_PANEL);visual_border_rect(18,58,250,174,1,UFT_RGB(42,68,80));
    visual_text(UFT_FONT_EB16,34,73,UFT_WHITE,"FIFA 15 PACK OPENER");snprintf(b,sizeof(b),"%d SOBRES ABIERTOS",packs_opened);visual_text(UFT_FONT_R9,34,98,UFT_MUTED,b);
    for(i=0;i<5;i++){int y=122+i*21;if(home_menu==i){visual_fill_rect(30,y-5,224,19,UFT_RGB(28,72,74));visual_fill_rect(30,y-5,4,19,UFT_ACCENT);}visual_text(UFT_FONT_R12,42,y,home_menu==i?UFT_WHITE:UFT_GREY,items[i]);}
    if(fut15_card_count>=3){visual_draw_card_mini(292,104,&fut15_cards[2],0);visual_draw_card_mini(336,84,&fut15_cards[1],0);visual_draw_card_mini(380,64,&fut15_cards[0],0);}
    visual_text(UFT_FONT_R9,292,198,UFT_MUTED,"21 DISENOS DE CARTA");if(visual_missing_assets()||visual_missing_fonts()){snprintf(b,sizeof(b),"ERRORES ASSET %d / FUENTE %d",visual_missing_assets(),visual_missing_fonts());visual_text(UFT_FONT_R9,292,216,UFT_YELLOW,b);}
    visual_footer("CRUCETA MOVER     X ACEPTAR     START SALIR");
}
static void draw_pack(void){
    int i;char b[128];visual_header(pack_lab?"SOBRE LAB / PROBABILIDAD TEST":"SOBRE NORMAL");snprintf(b,sizeof(b),"SOBRE #%d    %s",packs_opened,pack_lab?"35% ESPECIAL POR CARTA":"PROBABILIDAD ESPECIAL BAJA");visual_text(UFT_FONT_R9,16,51,UFT_MUTED,b);
    for(i=0;i<6;i++){int x=10+i*78,y=76;if(i==pack_sel){visual_fill_rect(x-4,y-4,78,96,UFT_RGB(31,47,58));visual_border_rect(x-4,y-4,78,96,2,UFT_YELLOW);}visual_draw_card_mini(x,y,&fut15_cards[pack_cards[i]],!revealed[i]);}
    visual_fill_rect(16,180,448,51,UFT_PANEL2);visual_border_rect(16,180,448,51,1,UFT_RGB(43,67,79));
    if(revealed[pack_sel]){const Fut15Card*c=&fut15_cards[pack_cards[pack_sel]];snprintf(b,sizeof(b),"%d %s  %s",c->rating,c->position,c->name);visual_text(UFT_FONT_EB16,28,190,UFT_WHITE,b);snprintf(b,sizeof(b),"%s  /  %s",c->club,visual_card_type_label(c));visual_text(UFT_FONT_R9,28,214,UFT_GREY,b);}else{visual_text(UFT_FONT_EB15,28,190,UFT_WHITE,"PULSA X PARA REVELAR");visual_text(UFT_FONT_R9,28,214,UFT_MUTED,"TRIANGULO REVELA LAS 6 CARTAS");}
    visual_footer("IZQ/DER ELEGIR     X REVELAR/ABRIR     TRIANGULO TODAS     O VOLVER");
}
static void draw_side(const Fut15Card*c,const char*mode){char b[128];visual_fill_rect(184,58,280,174,UFT_PANEL);visual_border_rect(184,58,280,174,1,UFT_RGB(43,67,79));visual_text(UFT_FONT_EB16,202,74,UFT_YELLOW,mode);visual_text(UFT_FONT_EB16,202,101,UFT_WHITE,c->name);visual_text(UFT_FONT_R12,202,126,UFT_GREY,c->club);visual_text(UFT_FONT_R9,202,148,UFT_MUTED,c->league);snprintf(b,sizeof(b),"TIPO: %s",visual_card_type_label(c));visual_text(UFT_FONT_R12,202,174,UFT_ACCENT,b);snprintf(b,sizeof(b),"VERSION DB: %s",c->version);visual_text(UFT_FONT_R9,202,198,UFT_GREY,b);}
static void draw_detail(void){visual_header("DETALLE DE CARTA");visual_draw_card_full(16,44,&fut15_cards[detail_index]);draw_side(&fut15_cards[detail_index],"CARTA DEL SOBRE");visual_text(UFT_FONT_R9,202,219,UFT_MUTED,"O VOLVER   IZQ/DER CAMBIAR");}
static void draw_database(void){char b[64];visual_header("BASE DE DATOS FUT 15");visual_draw_card_full(16,44,&fut15_cards[db_index]);snprintf(b,sizeof(b),"CARTA %u / %u",db_index+1,fut15_card_count);draw_side(&fut15_cards[db_index],b);visual_text(UFT_FONT_R9,202,219,UFT_MUTED,"ARR/ABA +/-50  TRIANGULO ALEATORIA  O VOLVER");}
static void draw_types(void){int start=types_page*8,i;char b[32];visual_header("GALERIA DE TIPOS");snprintf(b,sizeof(b),"PAGINA %d / 3",types_page+1);visual_text(UFT_FONT_R9,398,31,UFT_MUTED,b);for(i=0;i<8;i++){int idx=start+i,col=i%4,row=i/4,x=27+col*114,y=58+row*91;if(idx>=visual_type_count())break;visual_draw_type_preview(idx,x,y);}visual_footer("IZQ/DER PAGINA     O VOLVER");}
static void render(void){if(screen==SCR_HOME)draw_home();else if(screen==SCR_PACK)draw_pack();else if(screen==SCR_DETAIL)draw_detail();else if(screen==SCR_DATABASE)draw_database();else draw_types();dirty=0;}
static unsigned int pressed(unsigned int now,unsigned int old,unsigned int mask){return(now&mask)&&!(old&mask);}

int main(int argc,char *argv[]){SceCtrlData pad;unsigned int old=0;setup_callbacks();sceCtrlSetSamplingCycle(0);sceCtrlSetSamplingMode(PSP_CTRL_MODE_ANALOG);set_base_dir(argc,argv);visual_init(base_dir);srand((unsigned int)sceKernelGetSystemTimeLow());while(1){sceCtrlPeekBufferPositive(&pad,1);if(pressed(pad.Buttons,old,PSP_CTRL_START))sceKernelExitGame();
    if(screen==SCR_HOME){if(pressed(pad.Buttons,old,PSP_CTRL_UP)){home_menu=(home_menu+4)%5;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_DOWN)){home_menu=(home_menu+1)%5;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_CROSS)){if(home_menu==0)open_pack(1);else if(home_menu==1)open_pack(0);else if(home_menu==2){db_index=0;screen=SCR_DATABASE;dirty=1;}else if(home_menu==3){types_page=0;screen=SCR_TYPES;dirty=1;}else sceKernelExitGame();}}
    else if(screen==SCR_PACK){if(pressed(pad.Buttons,old,PSP_CTRL_LEFT)){pack_sel=(pack_sel+5)%6;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_RIGHT)){pack_sel=(pack_sel+1)%6;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_TRIANGLE)){int i;for(i=0;i<6;i++)revealed[i]=1;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_CROSS)){if(!revealed[pack_sel]){revealed[pack_sel]=1;dirty=1;}else{detail_index=pack_cards[pack_sel];detail_return=SCR_PACK;screen=SCR_DETAIL;dirty=1;}}if(pressed(pad.Buttons,old,PSP_CTRL_CIRCLE)){screen=SCR_HOME;dirty=1;}}
    else if(screen==SCR_DETAIL){if(pressed(pad.Buttons,old,PSP_CTRL_LEFT)){pack_sel=(pack_sel+5)%6;revealed[pack_sel]=1;detail_index=pack_cards[pack_sel];dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_RIGHT)){pack_sel=(pack_sel+1)%6;revealed[pack_sel]=1;detail_index=pack_cards[pack_sel];dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_CIRCLE)){screen=detail_return;dirty=1;}}
    else if(screen==SCR_DATABASE){if(pressed(pad.Buttons,old,PSP_CTRL_LEFT)){db_index=(db_index==0?fut15_card_count-1:db_index-1);dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_RIGHT)){db_index=(db_index+1)%fut15_card_count;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_UP)){db_index=(db_index+fut15_card_count-(50%fut15_card_count))%fut15_card_count;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_DOWN)){db_index=(db_index+50)%fut15_card_count;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_TRIANGLE)){db_index=rand()%(int)fut15_card_count;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_CIRCLE)){screen=SCR_HOME;dirty=1;}}
    else if(screen==SCR_TYPES){if(pressed(pad.Buttons,old,PSP_CTRL_LEFT)){types_page=(types_page+2)%3;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_RIGHT)){types_page=(types_page+1)%3;dirty=1;}if(pressed(pad.Buttons,old,PSP_CTRL_CIRCLE)){screen=SCR_HOME;dirty=1;}}
    if(dirty)render();old=pad.Buttons;sceDisplayWaitVblankStart();}return 0;}
