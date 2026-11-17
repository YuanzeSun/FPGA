#include "engine.h"
uint16_t snake_body[560],snake_length,snake_food;
uint8_t snake_direction,snake_state,snake_occupied[70];
static int occupied(unsigned n){return (snake_occupied[n>>3]>>(n&7))&1;}
static void mark(unsigned n,int value){if(value)snake_occupied[n>>3]|=(uint8_t)(1u<<(n&7));else snake_occupied[n>>3]&=(uint8_t)~(1u<<(n&7));}
static void food(void){
    unsigned n=random32()%560;
    while(occupied(n))n=n==559?0:n+1;
    snake_food=(uint16_t)n;
}
void snake_init(void){
    for(unsigned i=0;i<70;i++)snake_occupied[i]=0;
    snake_length=3;snake_direction=1;snake_state=0;
    for(unsigned i=0;i<3;i++){snake_body[i]=(uint16_t)(5-i);mark(5-i,1);}food();
}
void snake_update(unsigned buttons,int automatic){
    if(snake_state)return;
    int x=snake_body[0]%28,y=snake_body[0]/28;
    unsigned dir=snake_direction;
    if(automatic){ // A Hamiltonian cycle: safely traverses every board cell.
        if(x==0)dir=y?0:1;
        else if(!(y&1))dir=x<27?1:2;
        else dir=x>1?3:y<19?2:3;
    }else{
        unsigned wanted=buttons&UP?0:buttons&RIGHT?1:buttons&DOWN?2:buttons&LEFT?3:dir;
        if(wanted!=(dir^2u))dir=wanted;
    }
    snake_direction=(uint8_t)dir;
    if(dir==0)y--;else if(dir==1)x++;else if(dir==2)y++;else x--;
    if(x<0||x>=28||y<0||y>=20){snake_state=1;return;}
    unsigned n=(unsigned)(y*28+x),grow=n==snake_food;
    unsigned tail=snake_body[snake_length-1];
    if(occupied(n)&&(grow||n!=tail)){snake_state=1;return;}
    if(!grow)mark(tail,0);
    else snake_length++;
    for(unsigned i=snake_length-1;i>0;i--)snake_body[i]=snake_body[i-1];
    snake_body[0]=(uint16_t)n;mark(n,1);
    if(snake_length==560)snake_state=2;
    else if(grow)food();
}
void snake_draw(void){
    rectangle(5,4,30,22,1,SLATE,DARK);rectangle(6,5,28,20,' ',DARK,DARK);
    for(unsigned i=snake_length;i>0;i--){unsigned n=snake_body[i-1];put(6+(int)(n%28),5+(int)(n/28),i==1?3:2,i==1?CYAN:GREEN,DARK);}
    if(snake_state!=2)put(6+snake_food%28,5+snake_food/28,5,PINK,DARK);
    text(6,27,"ARROWS/WASD  EAT PINK HEARTS",MUTED,DARK);
}
