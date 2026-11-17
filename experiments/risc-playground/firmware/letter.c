#include "engine.h"
#include "letter_text.h"
uint16_t letter_reveal,letter_clock;
uint8_t letter_open;
static unsigned previous_buttons;
void letter_init(void){letter_reveal=0;letter_clock=0;letter_open=0;previous_buttons=0;}
void letter_update(unsigned buttons,int automatic){
    letter_clock++;
    int press=(buttons&FIRE)&&!(previous_buttons&FIRE);previous_buttons=buttons;
    if(!letter_open){if(press||(automatic&&letter_clock>=20)){letter_open=1;letter_clock=0;}}
    else if(press)letter_reveal=LETTER_LENGTH;
    else if(letter_reveal<LETTER_LENGTH)letter_reveal++;
}
static void chinese(int x,int y,const uint8_t *s,uint8_t color,uint8_t bg){while(*s)put(x++,y,*s++,color,bg);}
static void heart(int x,int y,unsigned color){
    static const uint8_t rows[6]={0x36,0x7f,0x7f,0x3e,0x1c,0x08};
    for(int r=0;r<6;r++)for(int c=0;c<7;c++)if(rows[r]&(1u<<(6-c)))put(x+c,y+r,4,(uint8_t)color,PLUM);
}
void letter_draw(void){
    background(PLUM);text(2,1,"RISC-V / A LETTER FOR YOU",PAPER,PLUM);
    if(!letter_open){
        chinese(10,6,letter_intro,PAPER,PLUM);
        rectangle(8,11,24,11,' ',PAPER,PAPER);
        for(int row=0;row<6;row++){
            put(8+row*2,11+row,'\\',WINE,PAPER);put(31-row*2,11+row,'/',WINE,PAPER);
            put(9+row*2,11+row,'\\',WINE,PAPER);put(30-row*2,11+row,'/',WINE,PAPER);
        }
        put(19,17,5,ROSE,PAPER);chinese(12,25,letter_prompt,PINK,PLUM);
    }else{
        heart(16,3,(letter_clock&2)?PINK:ROSE);
        unsigned visible=0;int x=5,y=11;
        for(unsigned i=0;i<LETTER_LENGTH&&visible<letter_reveal;i++,visible++){
            uint8_t ch=letter_body[i];
            if(ch=='\n'){x=5;y++;}else put(x++,y,ch,PAPER,PLUM);
        }
        if(letter_reveal>=LETTER_LENGTH)chinese(12,26,letter_end,PINK,PLUM);
    }
    text(2,29,"F/J OPEN/SKIP   R REPLAY   1/2/3 GAMES",MUTED,PLUM);
}
