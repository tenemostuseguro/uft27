#include <pspkernel.h>
#include <pspdebug.h>
#include <pspctrl.h>
#include <pspdisplay.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

PSP_MODULE_INFO("UFT 11 Prototype", 0, 1, 0);
PSP_MAIN_THREAD_ATTR(PSP_THREAD_ATTR_USER | PSP_THREAD_ATTR_VFPU);

#define SCREEN_W 60
#define PITCH_LEFT 1
#define PITCH_RIGHT 58
#define PITCH_TOP 4
#define PITCH_BOTTOM 29

#define COL_WHITE  0xFFFFFFFF
#define COL_GREY   0xFFB8B8B8
#define COL_GREEN  0xFF67E89A
#define COL_YELLOW 0xFF5BE7FF
#define COL_RED    0xFF6A6AFF
#define COL_BLUE   0xFFFFB56A
#define COL_GOLD   0xFF49C8FF

#define PACK_COST 750
#define ARRAY_COUNT(x) ((int)(sizeof(x) / sizeof((x)[0])))

typedef struct { const char *name; const char *pos; int ovr; } Card;
typedef struct { int x; int y; } Point;
typedef enum { SCREEN_HOME=0, SCREEN_SQUAD, SCREEN_PACK, SCREEN_MATCH, SCREEN_RESULT } Screen;

static const Card squad[11] = {
    {"Alvarez","POR",82},{"Vega","LD",80},{"Soler","DFC",84},{"Rivas","DFC",83},{"Navarro","LI",81},
    {"Leon","MCD",84},{"Campos","MC",86},{"Prieto","MC",85},{"Vidal","ED",87},{"Mora","DC",88},{"Gil","EI",86}
};

static const Card packPool[] = {
    {"Santos","POR",78},{"Herrera","DFC",79},{"Ruiz","LD",76},{"Torres","LI",77},{"Cano","MCD",80},
    {"Barros","MC",82},{"Serra","MCO",83},{"Costa","ED",81},{"Blanco","EI",80},{"Duran","DC",84},
    {"Rey","DFC",75},{"Roca","MC",74},{"Navas","POR",72},{"Vera","DC",77},{"Alba","MCO",85}
};

static Point homePlayers[11], awayPlayers[11];
static int selectedHome=0, homeMenu=0, coins=12500, packsOpened=0;
static int scoreHome=0, scoreAway=0, matchMinute=0, matchFrame=0;
static int homePossession=1, ballOwnerHome=9, ballOwnerAway=9;
static int lastPack[3]={0,1,2};
static Screen screen=SCREEN_HOME;

static int exit_callback(int a,int b,void *c){(void)a;(void)b;(void)c;sceKernelExitGame();return 0;}
static int callback_thread(SceSize a,void *b){(void)a;(void)b;int cb=sceKernelCreateCallback("Exit Callback",exit_callback,NULL);sceKernelRegisterExitCallback(cb);sceKernelSleepThreadCB();return 0;}
static void setup_callbacks(void){int th=sceKernelCreateThread("callback_thread",callback_thread,0x11,0xFA0,0,NULL);if(th>=0)sceKernelStartThread(th,0,NULL);}

static void color(unsigned int c){pspDebugScreenSetTextColor(c);}
static void text(int x,int y,unsigned int c,const char *s){pspDebugScreenSetXY(x,y);color(c);pspDebugScreenPrintf("%s",s);}
static void chr(int x,int y,unsigned int c,char ch){pspDebugScreenSetXY(x,y);color(c);pspDebugScreenPrintf("%c",ch);}
static void center(int y,unsigned int c,const char *s){int x=(SCREEN_W-(int)strlen(s))/2;if(x<0)x=0;text(x,y,c,s);}

static void header(const char *section){
    char b[96]; pspDebugScreenClear();
    snprintf(b,sizeof(b),"UFT 11 PORTABLE  |  %s",section); text(1,0,COL_GREEN,b);
    snprintf(b,sizeof(b),"Coins: %d   Packs: %d",coins,packsOpened); text(1,1,COL_GREY,b);
    text(1,2,COL_GREY,"----------------------------------------------------------");
}
static void footer(const char *s){text(1,31,COL_GREY,"----------------------------------------------------------");text(1,32,COL_GREY,s);}

static void resetPositions(void){
    Point hp[11]={{5,17},{14,7},{14,13},{14,21},{14,27},{25,17},{29,10},{29,24},{40,8},{43,17},{40,26}};
    Point ap[11]={{54,17},{45,7},{45,13},{45,21},{45,27},{34,17},{31,10},{31,24},{20,8},{17,17},{20,26}};
    memcpy(homePlayers,hp,sizeof(hp)); memcpy(awayPlayers,ap,sizeof(ap));
    selectedHome=9; homePossession=1; ballOwnerHome=9; ballOwnerAway=9;
}
static void resetMatch(void){scoreHome=0;scoreAway=0;matchMinute=0;matchFrame=0;resetPositions();}
static void kickoff(int toHome){resetPositions();homePossession=toHome;if(toHome){ballOwnerHome=9;selectedHome=9;}else{ballOwnerAway=9;selectedHome=5;}}
static int clampi(int v,int lo,int hi){if(v<lo)return lo;if(v>hi)return hi;return v;}
static int distance(Point a,Point b){int x=a.x-b.x,y=a.y-b.y;if(x<0)x=-x;if(y<0)y=-y;return x+y;}

static void drawHome(void){
    static const char *items[]={"JUGAR PARTIDO","PLANTILLA 4-3-3","ABRIR SOBRE","SALIR"};
    int i; header("ULTIMATE TEAM"); center(5,COL_WHITE,"ULTIMATE TEAM - FUTBOL 11"); center(7,COL_GREY,"Prototype v0.2 for PSP / PPSSPP");
    for(i=0;i<4;i++){char b[64];snprintf(b,sizeof(b),"%s %s",homeMenu==i?">":" ",items[i]);text(14,12+i*3,homeMenu==i?COL_GREEN:COL_WHITE,b);} footer("D-Pad: mover   X: aceptar   START: salir");
}

static void drawSquad(void){
    header("PLANTILLA"); center(4,COL_WHITE,"UFT CORDOBA  |  4-3-3");
    text(5,8,COL_GOLD,"EI 86 Gil"); center(8,COL_GOLD,"DC 88 Mora"); text(44,8,COL_GOLD,"Vidal 87 ED");
    text(11,14,COL_GOLD,"MC 86 Campos"); center(17,COL_GOLD,"MCD 84 Leon"); text(39,14,COL_GOLD,"Prieto 85 MC");
    text(3,23,COL_GOLD,"LI 81 Navarro"); text(18,22,COL_GOLD,"DFC 83 Rivas"); text(34,22,COL_GOLD,"Soler 84 DFC"); text(48,23,COL_GOLD,"Vega 80 LD"); center(27,COL_GOLD,"POR 82 Alvarez");
    footer("O: volver");
}

static void openPack(void){int i;if(coins<PACK_COST)return;coins-=PACK_COST;packsOpened++;for(i=0;i<3;i++)lastPack[i]=rand()%ARRAY_COUNT(packPool);}
static void drawPack(void){int i;header("SOBRE ORO");center(5,COL_YELLOW,"SOBRE ABIERTO");for(i=0;i<3;i++){const Card *c=&packPool[lastPack[i]];char b[80];snprintf(b,sizeof(b),"%d  %-4s  %s",c->ovr,c->pos,c->name);center(10+i*5,c->ovr>=80?COL_GOLD:COL_WHITE,b);}footer("X: abrir otro (750)   O: volver");}

static void drawPitch(void){
    int x,y,i;char b[96];pspDebugScreenClear();
    snprintf(b,sizeof(b),"UFT 11  %d-%d  CPU       %02d'",scoreHome,scoreAway,matchMinute);text(1,0,COL_WHITE,b);
    text(1,1,homePossession?COL_GREEN:COL_RED,homePossession?"POSESION: UFT":"POSESION: CPU");
    for(x=PITCH_LEFT;x<=PITCH_RIGHT;x++){chr(x,PITCH_TOP,COL_GREY,'-');chr(x,PITCH_BOTTOM,COL_GREY,'-');}
    for(y=PITCH_TOP;y<=PITCH_BOTTOM;y++){chr(PITCH_LEFT,y,COL_GREY,'|');chr(PITCH_RIGHT,y,COL_GREY,'|');chr(30,y,COL_GREY,y==17?'+':':');}
    for(y=15;y<=18;y++){chr(1,y,COL_GREY,'[');chr(58,y,COL_GREY,']');}
    for(i=0;i<11;i++){chr(homePlayers[i].x,homePlayers[i].y,i==selectedHome?COL_YELLOW:COL_BLUE,i==selectedHome?'@':'o');chr(awayPlayers[i].x,awayPlayers[i].y,COL_RED,'x');}
    if(homePossession)chr(homePlayers[ballOwnerHome].x+1,homePlayers[ballOwnerHome].y,COL_WHITE,'*');else chr(awayPlayers[ballOwnerAway].x-1,awayPlayers[ballOwnerAway].y,COL_WHITE,'*');
    text(1,31,COL_GREY,"D-Pad mover  X pase/entrada  O tiro  TRIANGULO cambiar");text(1,32,COL_GREY,"START: abandonar partido");
}

static int chooseForwardPass(int from){int i,best=from,bestScore=-9999;for(i=0;i<11;i++){int s;if(i==from)continue;s=(homePlayers[i].x-homePlayers[from].x)*4-abs(homePlayers[i].y-homePlayers[from].y)+(rand()%8);if(s>bestScore){bestScore=s;best=i;}}return best;}
static void passOrTackle(void){if(homePossession){int r=chooseForwardPass(ballOwnerHome);ballOwnerHome=r;selectedHome=r;if((rand()%100)<12){homePossession=0;ballOwnerAway=rand()%11;}}else if(distance(homePlayers[selectedHome],awayPlayers[ballOwnerAway])<=3&&(rand()%100)<65){homePossession=1;ballOwnerHome=selectedHome;}}
static void shoot(void){int chance;if(!homePossession||ballOwnerHome!=selectedHome)return;chance=8;if(homePlayers[selectedHome].x>=38)chance=25;if(homePlayers[selectedHome].x>=47)chance=55;if((rand()%100)<chance){scoreHome++;kickoff(0);}else{homePossession=0;ballOwnerAway=0;}}

static void updateOpponent(void){
    Point *p;if(homePossession)return;p=&awayPlayers[ballOwnerAway];
    if((matchFrame%10)==0){if(p->x>7)p->x--;if(p->y<17&&(rand()%2))p->y++;else if(p->y>17&&(rand()%2))p->y--;}
    if((matchFrame%40)==0&&(rand()%100)<18)ballOwnerAway=rand()%11;
    if(p->x<=8){if((rand()%100)<38)scoreAway++;kickoff(1);}
}
static void moveSelected(int dx,int dy){Point *p=&homePlayers[selectedHome];p->x=clampi(p->x+dx,PITCH_LEFT+1,PITCH_RIGHT-1);p->y=clampi(p->y+dy,PITCH_TOP+1,PITCH_BOTTOM-1);}
static void updateMatch(void){matchFrame++;if((matchFrame%15)==0&&matchMinute<90)matchMinute++;updateOpponent();if(matchMinute>=90)screen=SCREEN_RESULT;}

static void drawResult(void){char b[96];int reward=scoreHome>=scoreAway?600:300;header("FINAL");center(8,COL_WHITE,"FINAL DEL PARTIDO");snprintf(b,sizeof(b),"UFT 11   %d - %d   CPU",scoreHome,scoreAway);center(12,COL_YELLOW,b);snprintf(b,sizeof(b),"Recompensa: %d monedas",reward);center(17,COL_GREEN,b);center(22,COL_GREY,"X: cobrar y volver al menu");}
static unsigned int pressed(unsigned int now,unsigned int old,unsigned int mask){return(now&mask)&&!(old&mask);}

int main(int argc,char *argv[]){
    SceCtrlData pad;unsigned int oldButtons=0;int moveRepeat=0;(void)argc;(void)argv;(void)squad;
    setup_callbacks();pspDebugScreenInit();pspDebugScreenEnableBackColor(1);pspDebugScreenSetBackColor(0xFF0C1510);sceCtrlSetSamplingCycle(0);sceCtrlSetSamplingMode(PSP_CTRL_MODE_ANALOG);srand((unsigned int)sceKernelGetSystemTimeLow());resetMatch();
    while(1){
        sceCtrlPeekBufferPositive(&pad,1);
        if(pad.Buttons&PSP_CTRL_START){if(screen==SCREEN_MATCH)screen=SCREEN_HOME;else sceKernelExitGame();}
        if(screen==SCREEN_HOME){
            if(pressed(pad.Buttons,oldButtons,PSP_CTRL_UP))homeMenu=(homeMenu+3)%4;
            if(pressed(pad.Buttons,oldButtons,PSP_CTRL_DOWN))homeMenu=(homeMenu+1)%4;
            if(pressed(pad.Buttons,oldButtons,PSP_CTRL_CROSS)){if(homeMenu==0){resetMatch();screen=SCREEN_MATCH;}else if(homeMenu==1)screen=SCREEN_SQUAD;else if(homeMenu==2){openPack();screen=SCREEN_PACK;}else sceKernelExitGame();}
            drawHome();
        }else if(screen==SCREEN_SQUAD){if(pressed(pad.Buttons,oldButtons,PSP_CTRL_CIRCLE))screen=SCREEN_HOME;drawSquad();}
        else if(screen==SCREEN_PACK){if(pressed(pad.Buttons,oldButtons,PSP_CTRL_CIRCLE))screen=SCREEN_HOME;if(pressed(pad.Buttons,oldButtons,PSP_CTRL_CROSS)&&coins>=PACK_COST)openPack();drawPack();}
        else if(screen==SCREEN_MATCH){
            int dx=0,dy=0;if(pad.Buttons&(PSP_CTRL_UP|PSP_CTRL_DOWN|PSP_CTRL_LEFT|PSP_CTRL_RIGHT)){if(moveRepeat<=0){if(pad.Buttons&PSP_CTRL_UP)dy=-1;if(pad.Buttons&PSP_CTRL_DOWN)dy=1;if(pad.Buttons&PSP_CTRL_LEFT)dx=-1;if(pad.Buttons&PSP_CTRL_RIGHT)dx=1;moveSelected(dx,dy);moveRepeat=3;}else moveRepeat--;}else moveRepeat=0;
            if(pressed(pad.Buttons,oldButtons,PSP_CTRL_TRIANGLE)){selectedHome=(selectedHome+1)%11;if(homePossession)ballOwnerHome=selectedHome;}
            if(pressed(pad.Buttons,oldButtons,PSP_CTRL_CROSS))passOrTackle();if(pressed(pad.Buttons,oldButtons,PSP_CTRL_CIRCLE))shoot();updateMatch();drawPitch();
        }else if(screen==SCREEN_RESULT){if(pressed(pad.Buttons,oldButtons,PSP_CTRL_CROSS)){coins+=(scoreHome>=scoreAway)?600:300;screen=SCREEN_HOME;}drawResult();}
        oldButtons=pad.Buttons;sceDisplayWaitVblankStart();
    }
    return 0;
}
