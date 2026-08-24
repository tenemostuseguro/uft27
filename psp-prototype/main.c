#include <pspkernel.h>
#include <pspdebug.h>
#include <pspctrl.h>
#include <pspdisplay.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "fut15_data.h"

PSP_MODULE_INFO("UFT FUT15 Cards", 0, 0, 3);
PSP_MAIN_THREAD_ATTR(PSP_THREAD_ATTR_USER | PSP_THREAD_ATTR_VFPU);

#define SCREEN_W 60
#define COL_WHITE  0xFFFFFFFF
#define COL_BLACK  0xFF101010
#define COL_GREY   0xFFB8B8B8
#define COL_DARK   0xFF171B1D
#define COL_GREEN  0xFF67E89A
#define COL_YELLOW 0xFF5BE7FF
#define COL_BLUE   0xFFFFB56A
#define COL_RED    0xFF6A6AFF

typedef enum { SCR_HOME=0, SCR_PACK, SCR_DETAIL, SCR_DATABASE, SCR_TYPES } Screen;

static Screen screen=SCR_HOME;
static int homeMenu=0;
static int packCards[6]={0,0,0,0,0,0};
static unsigned char revealed[6]={0,0,0,0,0,0};
static int packSel=0, packModeLab=1, packsOpened=0;
static unsigned int dbIndex=0;
static int detailIndex=0;
static Screen detailReturn=SCR_PACK;

static int exit_callback(int a,int b,void *c){(void)a;(void)b;(void)c;sceKernelExitGame();return 0;}
static int callback_thread(SceSize a,void *b){(void)a;(void)b;int cb=sceKernelCreateCallback("Exit Callback",exit_callback,NULL);sceKernelRegisterExitCallback(cb);sceKernelSleepThreadCB();return 0;}
static void setup_callbacks(void){int th=sceKernelCreateThread("callback_thread",callback_thread,0x11,0xFA0,0,NULL);if(th>=0)sceKernelStartThread(th,0,NULL);}

static void set_bg(unsigned int c){pspDebugScreenSetBackColor(c);}
static void text_bg(int x,int y,unsigned int fg,unsigned int bg,const char *s){
    pspDebugScreenSetXY(x,y); pspDebugScreenSetTextColor(fg); set_bg(bg); pspDebugScreenPrintf("%s",s); set_bg(COL_DARK);
}
static void text(int x,int y,unsigned int c,const char *s){text_bg(x,y,c,COL_DARK,s);}
static void center(int y,unsigned int c,const char *s){int x=(SCREEN_W-(int)strlen(s))/2;if(x<0)x=0;text(x,y,c,s);}
static void fill_box(int x,int y,int w,int h,unsigned int bg){
    int r; char line[64]; if(w>60)w=60; memset(line,' ',w);line[w]=0;
    for(r=0;r<h;r++) text_bg(x,y+r,COL_WHITE,bg,line);
}
static void put_trunc(int x,int y,unsigned int fg,unsigned int bg,const char *s,int width){
    char b[64]; int n=(int)strlen(s); if(n>width)n=width; memcpy(b,s,n);b[n]=0;text_bg(x,y,fg,bg,b);
}
static unsigned int pressed(unsigned int now,unsigned int old,unsigned int mask){return (now&mask)&&!(old&mask);}

static int is_base_version(const char *v){
    return !strcmp(v,"Gold") || !strcmp(v,"Silver") || !strcmp(v,"Bronze") || !strcmp(v,"Gold_Non-rare");
}
static int is_special(const Fut15Card *c){return !is_base_version(c->version);}

static unsigned int card_bg(const Fut15Card *c){
    const char *v=c->version;
    if(!strcmp(v,"IF")) return 0xFF25221B;
    if(!strcmp(v,"TOTY")) return 0xFFC97212;
    if(!strcmp(v,"TOTS")) return 0xFF8A6514;
    if(!strcmp(v,"MOTM")) return 0xFF1D73E8;
    if(!strcmp(v,"POTY")) return 0xFFA83F69;
    if(!strcmp(v,"RB")) return 0xFF5C4ED8;
    if(!strcmp(v,"Futties")) return 0xFFC84CCB;
    if(!strcmp(v,"Legend")) return 0xFFE8E8D8;
    if(!strcmp(v,"Silver")) return 0xFFC0B9AA;
    if(!strcmp(v,"Bronze")) return 0xFF7A5B45;
    if(!strcmp(v,"Gold_Non-rare")) return 0xFFBCA879;
    return 0xFF2EA5CB;
}
static unsigned int card_fg(const Fut15Card *c){
    if(!strcmp(c->version,"Legend") || !strcmp(c->version,"Silver")) return COL_BLACK;
    return COL_WHITE;
}
static void clear_screen(void){set_bg(COL_DARK);pspDebugScreenClear();}
static void header(const char *title){
    char b[96]; clear_screen();
    snprintf(b,sizeof(b),"UFT PORTABLE  |  %s",title);text(1,0,COL_GREEN,b);
    snprintf(b,sizeof(b),"FUT 15 DB: %u cards  |  %u clubs  |  %u pos",
             fut15_card_count,fut15_club_count,fut15_position_count);text(1,1,COL_GREY,b);
    text(1,2,COL_GREY,"----------------------------------------------------------");
}
static void footer(const char *s){text(1,31,COL_GREY,"----------------------------------------------------------");text(1,32,COL_GREY,s);}

static int same_player_in_pack(int upto, int idx){
    int i;for(i=0;i<upto;i++) if(!strcmp(fut15_cards[packCards[i]].name,fut15_cards[idx].name)) return 1;return 0;
}
static int pick_by_type(int wantSpecial){
    int tries=0;int idx=0;
    do{
        idx=rand()%(int)fut15_card_count;
        tries++;
        if(!!is_special(&fut15_cards[idx])==!!wantSpecial) return idx;
    }while(tries<30000);
    return idx;
}
static void open_pack(int lab){
    int i; packsOpened++; packModeLab=lab; packSel=0;
    for(i=0;i<6;i++){
        int idx,tries=0;
        int specialRoll = lab ? ((rand()%100)<35) : ((rand()%1000)<12);
        do{idx=pick_by_type(specialRoll);tries++;}while(same_player_in_pack(i,idx)&&tries<100);
        packCards[i]=idx;revealed[i]=0;
    }
    screen=SCR_PACK;
}

static void draw_home(void){
    static const char *items[]={
        "ABRIR SOBRE LAB (35% ESPECIALES)",
        "ABRIR SOBRE NORMAL",
        "NAVEGAR BASE DE DATOS FUT 15",
        "TIPOS DE CARTA",
        "SALIR"
    };
    int i;char b[96];header("FIFA 15 CARD LAB");
    center(5,COL_WHITE,"ULTIMATE TEAM - CARD & PACK PROTOTYPE");
    snprintf(b,sizeof(b),"Sobres abiertos: %d  |  Especiales compilados: %u",packsOpened,fut15_special_count);center(7,COL_GREY,b);
    for(i=0;i<5;i++){
        snprintf(b,sizeof(b),"%s %s",homeMenu==i?">":" ",items[i]);
        text(7,11+i*3,homeMenu==i?COL_YELLOW:COL_WHITE,b);
    }
    footer("D-Pad mover | X aceptar | START salir");
}

static void draw_tile(int slot){
    int col=slot%3,row=slot/3;
    int x=2+col*19,y=5+row*13,w=17,h=11;
    char b[48];unsigned int bg,fg;
    if(slot==packSel) text(x-1,y,COL_YELLOW,">");
    if(!revealed[slot]){
        bg=0xFF33383A;fill_box(x,y,w,h,bg);
        text_bg(x+6,y+3,COL_WHITE,bg,"???");
        text_bg(x+3,y+6,COL_GREY,bg,"X REVELAR");
        return;
    }
    {
        const Fut15Card *c=&fut15_cards[packCards[slot]];
        bg=card_bg(c);fg=card_fg(c);fill_box(x,y,w,h,bg);
        snprintf(b,sizeof(b),"%d %-4s",c->rating,c->position);text_bg(x+1,y+1,fg,bg,b);
        put_trunc(x+1,y+3,fg,bg,c->name,15);
        put_trunc(x+1,y+5,fg,bg,c->club,15);
        put_trunc(x+1,y+7,fg,bg,c->version,15);
        snprintf(b,sizeof(b),"%02dP %02dS %02dD",c->pac,c->sho,c->dri);text_bg(x+1,y+9,fg,bg,b);
    }
}
static void draw_pack(void){
    int i;char b[80];header(packModeLab?"SOBRE LAB":"SOBRE NORMAL");
    snprintf(b,sizeof(b),"Sobre #%d - seleccion %d/6",packsOpened,packSel+1);center(3,COL_GREY,b);
    for(i=0;i<6;i++)draw_tile(i);
    footer("D-Pad seleccionar | X revelar/abrir | TRIANGULO todas | O menu");
}

static void draw_full_card(const Fut15Card *c,const char *title){
    unsigned int bg=card_bg(c),fg=card_fg(c);char b[96];
    header(title);fill_box(9,4,42,25,bg);
    snprintf(b,sizeof(b),"%d   %s",c->rating,c->position);text_bg(12,6,fg,bg,b);
    put_trunc(12,9,fg,bg,c->name,34);
    put_trunc(12,11,fg,bg,c->club,34);
    put_trunc(12,13,fg,bg,c->league,34);
    snprintf(b,sizeof(b),"VERSION: %s",c->version);put_trunc(12,15,fg,bg,b,34);
    snprintf(b,sizeof(b),"%02d PAC     %02d DRI",c->pac,c->dri);text_bg(12,18,fg,bg,b);
    snprintf(b,sizeof(b),"%02d SHO     %02d DEF",c->sho,c->def);text_bg(12,20,fg,bg,b);
    snprintf(b,sizeof(b),"%02d PAS     %02d PHY",c->pas,c->phy);text_bg(12,22,fg,bg,b);
    snprintf(b,sizeof(b),"ID DB: %d",detailIndex);text_bg(12,26,fg,bg,b);
}
static void draw_detail(void){
    draw_full_card(&fut15_cards[detailIndex],"DETALLE DE CARTA");
    footer("IZQ/DER otra carta del sobre | O volver");
}
static void draw_database(void){
    char title[80];detailIndex=(int)dbIndex;
    snprintf(title,sizeof(title),"BASE FUT15  %u/%u",dbIndex+1,fut15_card_count);
    draw_full_card(&fut15_cards[dbIndex],title);
    footer("IZQ/DER +/-1 | ARR/ABA +/-50 | TRIANGULO aleatoria | O menu");
}
static void draw_types(void){
    header("TIPOS DE CARTA FUT 15");
    text(3,5,COL_WHITE,"Base: Bronze | Silver | Gold | Gold Non-Rare");
    text(3,8,0xFF49C8FF,"IF / TOTW         - In Form semanal");
    text(3,10,0xFFC97212,"TOTY              - Team of the Year");
    text(3,12,0xFF8A6514,"TOTS              - Team of the Season");
    text(3,14,0xFF1D73E8,"MOTM              - Man of the Match");
    text(3,16,0xFFA83F69,"POTY / Hero       - especiales moradas");
    text(3,18,0xFF5C4ED8,"RB                - Record Breaker");
    text(3,20,0xFFC84CCB,"Futties           - FUTTIES");
    text(3,22,COL_WHITE,"Legend            - Legends (Xbox en FUT 15)");
    text(3,25,COL_GREY,"La BD compilada asigna versiones usando datos historicos");
    text(3,27,COL_GREY,"FUT15 y un catalogo de 720 cartas / 408 jugadores.");
    footer("O volver");
}

int main(int argc,char *argv[]){
    SceCtrlData pad;unsigned int old=0;(void)argc;(void)argv;
    setup_callbacks();pspDebugScreenInit();pspDebugScreenEnableBackColor(1);set_bg(COL_DARK);
    sceCtrlSetSamplingCycle(0);sceCtrlSetSamplingMode(PSP_CTRL_MODE_ANALOG);
    srand((unsigned int)sceKernelGetSystemTimeLow());
    while(1){
        sceCtrlPeekBufferPositive(&pad,1);
        if(pressed(pad.Buttons,old,PSP_CTRL_START))sceKernelExitGame();

        if(screen==SCR_HOME){
            if(pressed(pad.Buttons,old,PSP_CTRL_UP))homeMenu=(homeMenu+4)%5;
            if(pressed(pad.Buttons,old,PSP_CTRL_DOWN))homeMenu=(homeMenu+1)%5;
            if(pressed(pad.Buttons,old,PSP_CTRL_CROSS)){
                if(homeMenu==0)open_pack(1);
                else if(homeMenu==1)open_pack(0);
                else if(homeMenu==2){dbIndex=0;screen=SCR_DATABASE;}
                else if(homeMenu==3)screen=SCR_TYPES;
                else sceKernelExitGame();
            }
            draw_home();
        }else if(screen==SCR_PACK){
            if(pressed(pad.Buttons,old,PSP_CTRL_LEFT))packSel=(packSel+5)%6;
            if(pressed(pad.Buttons,old,PSP_CTRL_RIGHT))packSel=(packSel+1)%6;
            if(pressed(pad.Buttons,old,PSP_CTRL_UP))packSel=(packSel+3)%6;
            if(pressed(pad.Buttons,old,PSP_CTRL_DOWN))packSel=(packSel+3)%6;
            if(pressed(pad.Buttons,old,PSP_CTRL_TRIANGLE)){int i;for(i=0;i<6;i++)revealed[i]=1;}
            if(pressed(pad.Buttons,old,PSP_CTRL_CROSS)){
                if(!revealed[packSel])revealed[packSel]=1;
                else{detailIndex=packCards[packSel];detailReturn=SCR_PACK;screen=SCR_DETAIL;}
            }
            if(pressed(pad.Buttons,old,PSP_CTRL_CIRCLE))screen=SCR_HOME;
            if(screen==SCR_PACK)draw_pack();
        }else if(screen==SCR_DETAIL){
            if(pressed(pad.Buttons,old,PSP_CTRL_LEFT)){packSel=(packSel+5)%6;revealed[packSel]=1;detailIndex=packCards[packSel];}
            if(pressed(pad.Buttons,old,PSP_CTRL_RIGHT)){packSel=(packSel+1)%6;revealed[packSel]=1;detailIndex=packCards[packSel];}
            if(pressed(pad.Buttons,old,PSP_CTRL_CIRCLE))screen=detailReturn;
            if(screen==SCR_DETAIL)draw_detail();
        }else if(screen==SCR_DATABASE){
            if(pressed(pad.Buttons,old,PSP_CTRL_LEFT))dbIndex=(dbIndex==0?fut15_card_count-1:dbIndex-1);
            if(pressed(pad.Buttons,old,PSP_CTRL_RIGHT))dbIndex=(dbIndex+1)%fut15_card_count;
            if(pressed(pad.Buttons,old,PSP_CTRL_UP))dbIndex=(dbIndex+fut15_card_count-(50%fut15_card_count))%fut15_card_count;
            if(pressed(pad.Buttons,old,PSP_CTRL_DOWN))dbIndex=(dbIndex+50)%fut15_card_count;
            if(pressed(pad.Buttons,old,PSP_CTRL_TRIANGLE))dbIndex=rand()%(int)fut15_card_count;
            if(pressed(pad.Buttons,old,PSP_CTRL_CIRCLE))screen=SCR_HOME;
            if(screen==SCR_DATABASE)draw_database();
        }else if(screen==SCR_TYPES){
            if(pressed(pad.Buttons,old,PSP_CTRL_CIRCLE))screen=SCR_HOME;
            if(screen==SCR_TYPES)draw_types();
        }
        old=pad.Buttons;sceDisplayWaitVblankStart();
    }
    return 0;
}
