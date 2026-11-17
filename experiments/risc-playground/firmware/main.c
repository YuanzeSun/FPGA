#include "engine.h"
#ifndef HOST_TEST
#define REG(addr) (*(volatile uint32_t *)(addr))
#define UART_DIV REG(0x02000000u)
#define UART_DATA REG(0x02000004u)
#define FRAMES REG(0x02000010u)
#define FLIP REG(0x02000014u)
static unsigned game,automatic,paused,buttons,last_key;
static uint32_t command_count,last_input_frame;
static void serial_char(char c){UART_DATA=(uint8_t)c;}
static void serial_string(const char *s){while(*s)serial_char(*s++);}
static void hex(unsigned n,unsigned width){while(width){unsigned d=(n>>((--width)*4))&15u;serial_char((char)(d<10?'0'+d:'A'+d-10));}}
static void report(void){
    serial_string("RISC G=");hex(game,1);serial_string(" F=");hex(FRAMES,8);
    serial_string(" S=");hex(app_score(game),4);serial_string(" X=");hex(app_x(game),4);
    serial_string(" Y=");hex(app_y(game),4);serial_string(" T=");hex(app_state(game),1);
    serial_string(" A=");hex(automatic,1);serial_string(" P=");hex(paused,1);
    serial_string(" C=");hex(command_count,8);serial_string(" K=");hex(last_key,2);serial_string("\r\n");
}
static void debug(void){
    REG(0x02000024u)=app_score(game);REG(0x02000028u)=app_x(game);
    REG(0x0200002cu)=app_y(game);REG(0x02000034u)=last_key;
    REG(0x02000020u)=game|(automatic<<8)|(paused<<9)|(app_state(game)<<16);
    REG(0x02000030u)=command_count; // Commit marker: other status fields are now coherent.
}
static void draw(void){
    background(DARK);game_draw(game);
    if(game<4){
        text(1,0,game==1?"RISC-V / SNAKE":game==2?"RISC-V / MAZE":"RISC-V / BLOCKS",CYAN,DARK);
        text(1,2,"1 SNAKE 2 MAZE 3 BLOCKS 4 LETTER",MUTED,DARK);
        text(27,0,"SCORE",MUTED,DARK);number(33,0,app_score(game),WHITE);
        if(paused)text(12,3,"PAUSED",GOLD,DARK);
        else if(app_state(game))text(10,3,app_state(game)==2?"YOU WIN - R REPLAY":"GAME OVER - R REPLAY",PINK,DARK);
        text(1,29,"SPACE PAUSE  R RESET  TAB AUTO",MUTED,DARK);
        put(38,0,1,automatic?GREEN:GOLD,DARK);
    }else if(paused)text(29,1,"PAUSED",GOLD,PLUM);
    FLIP=1;
    while(FLIP&1u){} // Publish only at vertical blank, never a partial screen.
    debug();
}
int main(void){
    UART_DIV=217;game=1;automatic=1;random_state=0x21092026;
    game_init(game);draw();serial_string("RV32IMC GAMES READY\r\n");report();
    uint32_t previous=FRAMES,last_report=previous,terminal_since=0;
    for(;;){
        unsigned dirty=0,reply=0;
        uint32_t now=FRAMES;
        uint32_t input=UART_DATA;
        if(input!=0xffffffffu){
            last_key=input&255u;command_count++;reply=1;
            if(input&128u){buttons=input&63u;last_input_frame=now;if(buttons)automatic=0;}
            else if(input>='1'&&input<='4'){game=input-'0';game_init(game);paused=0;buttons=0;dirty=1;terminal_since=0;}
            else if(input=='r'){game_init(game);paused=0;buttons=0;dirty=1;terminal_since=0;}
            else if(input=='p'){paused=!paused;dirty=1;}
            else if(input=='m'){automatic=0;buttons=0;dirty=1;}
            else if(input=='a'){automatic=!automatic;buttons=0;if(automatic)game_init(game);dirty=1;terminal_since=0;}
        }
        if(now-last_input_frame>12)buttons=0;
        unsigned interval=game==1?8u:game==3&&automatic?30u:6u;
        if(now-previous>=interval){
            previous=now;
            if(!paused){
                if(game<4&&app_state(game)){
                    if(!terminal_since)terminal_since=now;
                    if(automatic&&now-terminal_since>=120){game_init(game);terminal_since=0;dirty=1;}
                }else{game_update(game,buttons,(int)automatic);dirty=1;}
            }
        }
        if(dirty)draw();
        else if(reply)debug();
        if(reply||now-last_report>=60){report();last_report=now;}
    }
}
#endif
