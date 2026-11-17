#include "engine.h"
uint32_t random_state;
uint32_t random32(void){
    uint32_t x=random_state?random_state:0x12345678u;
    x^=x<<13;x^=x>>17;x^=x<<5;return random_state=x;
}
#ifdef HOST_TEST
uint16_t screen[1200];
#else
#define screen ((volatile uint32_t *)0x03000000u)
#endif
void put(int x,int y,uint8_t ch,uint8_t fg,uint8_t bg){
    if(x>=0&&x<40&&y>=0&&y<30)screen[y*40+x]=(uint16_t)(ch|((unsigned)fg<<8)|((unsigned)bg<<12));
}
void rectangle(int x,int y,int w,int h,uint8_t ch,uint8_t fg,uint8_t bg){
    for(int row=0;row<h;row++)for(int col=0;col<w;col++)put(x+col,y+row,ch,fg,bg);
}
void background(uint8_t color){rectangle(0,0,40,30,' ',color,color);}
void text(int x,int y,const char *s,uint8_t fg,uint8_t bg){while(*s&&x<40)put(x++,y,(uint8_t)*s++,fg,bg);}
void number(int x,int y,unsigned value,uint8_t color){
    char digits[5];for(int i=3;i>=0;i--){digits[i]=(char)('0'+value%10);value/=10;}digits[4]=0;text(x,y,digits,color,DARK);
}
void game_init(unsigned g){if(g==1)snake_init();else if(g==2)maze_init();else if(g==3)blocks_init();else letter_init();}
void game_update(unsigned g,unsigned b,int a){if(g==1)snake_update(b,a);else if(g==2)maze_update(b,a);else if(g==3)blocks_update(b,a);else letter_update(b,a);}
void game_draw(unsigned g){if(g==1)snake_draw();else if(g==2)maze_draw();else if(g==3)blocks_draw();else letter_draw();}
unsigned app_score(unsigned g){return g==1?snake_length-3:g==2?maze_steps:g==3?blocks_score:letter_reveal;}
unsigned app_state(unsigned g){return g==1?snake_state:g==2?maze_state:g==3?blocks_state:letter_open;}
unsigned app_x(unsigned g){return g==1?snake_body[0]%28:g==2?maze_x:g==3?(unsigned)(blocks_x+2):letter_reveal;}
unsigned app_y(unsigned g){return g==1?snake_body[0]/28:g==2?maze_y:g==3?(unsigned)blocks_y:letter_clock;}
