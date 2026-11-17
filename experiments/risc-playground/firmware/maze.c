#include "engine.h"
uint8_t maze_map[651],maze_x,maze_y,maze_state;
uint16_t maze_steps;
static uint16_t work[651],parent[651];
static const int dx[4]={0,1,0,-1},dy[4]={-1,0,1,0};
void maze_init(void){
    for(unsigned i=0;i<651;i++)maze_map[i]=1;
    unsigned count=1;work[0]=32;maze_map[32]=0;
    while(count){
        unsigned n=work[count-1];int x=(int)(n%31),y=(int)(n/31);
        unsigned options[4],found=0;
        for(unsigned d=0;d<4;d++){
            int nx=x+2*dx[d],ny=y+2*dy[d];
            if(nx>0&&nx<30&&ny>0&&ny<20&&maze_map[ny*31+nx])options[found++]=d;
        }
        if(!found){count--;continue;}
        unsigned d=options[random32()%found];
        int middle=(y+dy[d])*31+x+dx[d],next=(y+2*dy[d])*31+x+2*dx[d];
        maze_map[middle]=0;maze_map[next]=0;work[count++]=(uint16_t)next;
    }
    // Parent links point toward the exit from every floor cell, so enabling
    // automatic play works even after the user has wandered off the initial path.
    for(unsigned i=0;i<651;i++)parent[i]=0xffff;
    unsigned head=0,tail=1;work[0]=618;parent[618]=618;
    while(head<tail){
        unsigned n=work[head++];int x=(int)(n%31),y=(int)(n/31);
        for(unsigned d=0;d<4;d++){
            int nx=x+dx[d],ny=y+dy[d],next=ny*31+nx;
            if(nx>=0&&nx<31&&ny>=0&&ny<21&&!maze_map[next]&&parent[next]==0xffff){parent[next]=(uint16_t)n;work[tail++]=(uint16_t)next;}
        }
    }
    maze_x=1;maze_y=1;maze_steps=0;maze_state=0;
}
void maze_update(unsigned buttons,int automatic){
    if(maze_state)return;
    unsigned d=4;
    if(automatic){
        unsigned n=maze_y*31u+maze_x,next=parent[n];
        d=next==n+1?1:next+1==n?3:next==n+31?2:0;
    } else d=buttons&UP?0:buttons&RIGHT?1:buttons&DOWN?2:buttons&LEFT?3:4;
    if(d==4)return;
    int x=maze_x+dx[d],y=maze_y+dy[d];
    if(x<0||x>=31||y<0||y>=21||maze_map[y*31+x])return;
    maze_x=(uint8_t)x;maze_y=(uint8_t)y;maze_steps++;
    if(x==29&&y==19)maze_state=2;
}
void maze_draw(void){
    for(int y=0;y<21;y++)for(int x=0;x<31;x++)put(4+x,5+y,maze_map[y*31+x]?4:' ',maze_map[y*31+x]?BLUE:DARK,DARK);
    put(33,24,5,GOLD,DARK);put(4+maze_x,5+maze_y,3,CYAN,DARK);
    text(4,27,"ARROWS/WASD  REACH GOLD HEART",MUTED,DARK);
}
