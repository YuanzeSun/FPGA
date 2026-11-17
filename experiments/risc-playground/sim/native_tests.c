#include <assert.h>
#include <stdio.h>
#include "engine.h"
#include "tetrominoes.h"
#include "letter_text.h"
extern uint16_t screen[1200];
static void test_snake(void){
    random_state=123;snake_init();snake_food=6;
    snake_update(0,0);assert(snake_body[0]==6&&snake_length==4);
    snake_update(LEFT,0);assert(snake_body[0]==7&&snake_direction==1);
    snake_update(UP,0);assert(snake_state==1);
    snake_init();
    for(int i=0;i<20000&&!snake_state;i++){
        snake_update(0,1);assert(snake_length>=3&&snake_length<=560);
        for(unsigned n=0;n<snake_length;n++)assert(snake_body[n]<560);
        assert(snake_state!=1);
    }
    snake_draw();
}
static void test_maze(void){
    for(unsigned seed=1;seed<=40;seed++){
        random_state=seed;maze_init();assert(maze_x==1&&maze_y==1&&!maze_state);
        maze_update(UP,0);assert(maze_x==1&&maze_y==1); // outer wall
        int i=0;while(!maze_state&&i++<651)maze_update(0,1);
        assert(maze_state==2&&maze_x==29&&maze_y==19&&maze_steps<320);
    }
    maze_init();maze_draw();
}
static void test_blocks(void){
    for(unsigned p=0;p<7;p++)for(unsigned r=0;r<4;r++){
        unsigned mask=shapes[p][r],count=0;
        for(int i=0;i<16;i++)if(mask&(1u<<i))count++;
        assert(count==4);
    }
    blocks_init();
    for(int x=0;x<8;x++){blocks_board[18][x]=2;blocks_board[19][x]=2;}
    blocks_piece=1;blocks_rotation=0;blocks_x=8;blocks_y=0;
    blocks_update(FIRE,0);assert(blocks_lines==2&&blocks_score==300&&!blocks_state);
    blocks_init();
    for(int x=4;x<10;x++)blocks_board[19][x]=2;
    blocks_lines=39;blocks_piece=0;blocks_rotation=0;blocks_x=0;blocks_y=0;
    blocks_update(FIRE,0);assert(blocks_state==2&&blocks_lines==40);
    blocks_init();
    for(int x=2;x<8;x++)blocks_board[0][x]=2;
    blocks_piece=1;blocks_x=4;blocks_y=16;
    blocks_update(FIRE,0);assert(blocks_state==1);
    for(int run=0;run<40;run++){
        blocks_init();int i=0;
        while(!blocks_state&&i++<300)blocks_update(0,1);
        for(int y=0;y<20;y++)for(int x=0;x<10;x++)assert(blocks_board[y][x]<=8);
        assert(blocks_state);
    }
    blocks_init();
    for(int i=0;i<10000;i++){
        if(blocks_state)blocks_init();
        blocks_update(random32()&63u,0);
        if(!blocks_state)assert(blocks_fits(blocks_x,blocks_y,blocks_piece,blocks_rotation));
    }
    blocks_draw();
}
static void test_letter(void){
    letter_init();letter_update(FIRE,0);assert(letter_open&&letter_reveal==0);
    letter_update(0,0);assert(letter_reveal==1);
    letter_update(FIRE,0);assert(letter_reveal==LETTER_LENGTH);
    letter_draw();
    letter_init();for(unsigned i=0;i<20+LETTER_LENGTH;i++)letter_update(0,1);
    assert(letter_open&&letter_reveal==LETTER_LENGTH);
}
static void save(const char *name){
    FILE *f=fopen(name,"w");assert(f);for(int i=0;i<1200;i++)fprintf(f,"%04x\n",screen[i]);fclose(f);
}
int main(void){
    test_snake();test_maze();test_blocks();test_letter();
    random_state=0x21092026;
    for(unsigned g=1;g<=4;g++){
        game_init(g);int steps=g==1?40:g==2?50:g==3?8:1;
        if(g==4)letter_update(FIRE,0);
        for(int i=0;i<steps;i++)game_update(g,0,1);
        background(DARK);game_draw(g);
        char path[64];snprintf(path,sizeof(path),"build/native-game%u.cells",g);save(path);
    }
    letter_init();letter_draw();save("build/native-letter-envelope.cells");
    letter_update(FIRE,0);letter_update(0,0);letter_update(FIRE,0);letter_draw();save("build/native-letter-full.cells");
    puts("TEST PASS: native C snake growth/reversal/walls, 40 generated mazes solved, all tetrominoes, line scoring/win/loss, auto/manual stress, letter replay/typewriter");
    return 0;
}
