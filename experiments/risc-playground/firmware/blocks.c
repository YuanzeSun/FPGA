#include "engine.h"
uint8_t blocks_board[20][10],blocks_piece,blocks_rotation,blocks_next,blocks_state;
int blocks_x,blocks_y;
uint16_t blocks_score,blocks_lines;
static unsigned gravity,old_buttons;
#include "tetrominoes.h"
int blocks_fits(int x,int y,unsigned piece,unsigned rotation){
    uint16_t mask=shapes[piece][rotation];
    for(int row=0;row<4;row++)for(int col=0;col<4;col++)if(mask&(1u<<(row*4+col))){
        int xx=x+col,yy=y+row;if(xx<0||xx>=10||yy<0||yy>=20||blocks_board[yy][xx])return 0;
    }return 1;
}
unsigned blocks_clear_lines(void){
    unsigned cleared=0;
    for(int y=19;y>=0;y--){
        int full=1;for(int x=0;x<10;x++)if(!blocks_board[y][x])full=0;
        if(full){
            cleared++;
            for(int yy=y;yy>0;yy--)for(int x=0;x<10;x++)blocks_board[yy][x]=blocks_board[yy-1][x];
            for(int x=0;x<10;x++)blocks_board[0][x]=0;
            y++;
        }
    }return cleared;
}
static void spawn(void){
    blocks_piece=blocks_next;blocks_next=(uint8_t)(random32()%7);blocks_rotation=0;blocks_x=3;blocks_y=0;gravity=0;
    if(!blocks_fits(blocks_x,blocks_y,blocks_piece,0))blocks_state=1;
}
void blocks_init(void){
    for(int y=0;y<20;y++)for(int x=0;x<10;x++)blocks_board[y][x]=0;
    blocks_next=(uint8_t)(random32()%7);blocks_score=0;blocks_lines=0;blocks_state=0;old_buttons=0;spawn();
}
static void lock_piece(void){
    uint16_t mask=shapes[blocks_piece][blocks_rotation];
    for(int row=0;row<4;row++)for(int col=0;col<4;col++)if(mask&(1u<<(row*4+col)))blocks_board[blocks_y+row][blocks_x+col]=(uint8_t)(blocks_piece+2);
    unsigned n=blocks_clear_lines();
    static const unsigned points[5]={0,100,300,500,800};
    blocks_score=(uint16_t)(blocks_score+points[n]);blocks_lines=(uint16_t)(blocks_lines+n);
    if(blocks_lines>=40)blocks_state=2;else spawn();
}
void blocks_update(unsigned buttons,int automatic){
    if(blocks_state)return;
    if(automatic){
        // Search valid landing positions. Prefer lower placements and fewer holes.
        int best=-100000,best_x=3,best_y=0;unsigned best_r=0;
        for(unsigned r=0;r<4;r++)for(int x=-2;x<10;x++){
            if(!blocks_fits(x,0,blocks_piece,r))continue;
            int y=0;while(blocks_fits(x,y+1,blocks_piece,r))y++;
            uint16_t mask=shapes[blocks_piece][r];int merit=y*12;
            for(int row=0;row<4;row++)for(int col=0;col<4;col++)if(mask&(1u<<(row*4+col))){
                int yy=y+row+1,xx=x+col;
                if(yy<20&&!(row<3&&(mask&(1u<<((row+1)*4+col))))&&!blocks_board[yy][xx])merit-=40;
            }
            if(merit>best){best=merit;best_x=x;best_y=y;best_r=r;}
        }
        blocks_x=best_x;blocks_y=best_y;blocks_rotation=(uint8_t)best_r;lock_piece();return;
    }
    if((buttons&LEFT)&&!(buttons&RIGHT)&&blocks_fits(blocks_x-1,blocks_y,blocks_piece,blocks_rotation))blocks_x--;
    if((buttons&RIGHT)&&!(buttons&LEFT)&&blocks_fits(blocks_x+1,blocks_y,blocks_piece,blocks_rotation))blocks_x++;
    if((buttons&(UP|ROTATE))&&!(old_buttons&(UP|ROTATE))){
        unsigned r=(blocks_rotation+1u)&3u;
        static const int kicks[5]={0,-1,1,-2,2};
        for(unsigned i=0;i<5;i++)if(blocks_fits(blocks_x+kicks[i],blocks_y,blocks_piece,r)){blocks_x+=kicks[i];blocks_rotation=(uint8_t)r;break;}
    }
    if((buttons&FIRE)&&!(old_buttons&FIRE)){
        while(blocks_fits(blocks_x,blocks_y+1,blocks_piece,blocks_rotation))blocks_y++;
        lock_piece();
    }else{
        gravity++;
        unsigned interval=blocks_lines>=30?3:blocks_lines>=20?5:blocks_lines>=10?7:10;
        if((buttons&DOWN)||gravity>=interval){
            gravity=0;if(blocks_fits(blocks_x,blocks_y+1,blocks_piece,blocks_rotation))blocks_y++;else lock_piece();
        }
    }
    old_buttons=buttons;
}
static void draw_shape(int x,int y,unsigned piece,unsigned rotation){
    uint16_t mask=shapes[piece][rotation];
    for(int row=0;row<4;row++)for(int col=0;col<4;col++)if(mask&(1u<<(row*4+col)))put(x+col,y+row,4,(uint8_t)(piece+2),DARK);
}
void blocks_draw(void){
    rectangle(11,4,12,22,1,SLATE,DARK);rectangle(12,5,10,20,' ',DARK,DARK);
    for(int y=0;y<20;y++)for(int x=0;x<10;x++)if(blocks_board[y][x])put(12+x,5+y,4,blocks_board[y][x],DARK);
    if(!blocks_state)draw_shape(12+blocks_x,5+blocks_y,blocks_piece,blocks_rotation);
    text(26,6,"NEXT",MUTED,DARK);draw_shape(26,8,blocks_next,0);
    text(26,15,"LINES",MUTED,DARK);number(26,17,blocks_lines,GOLD);
    text(2,27,"LEFT/RIGHT  UP ROTATE  F DROP",MUTED,DARK);
}
