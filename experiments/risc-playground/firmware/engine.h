#ifndef ENGINE_H
#define ENGINE_H
#include <stdint.h>
#define LEFT 1u
#define RIGHT 2u
#define UP 4u
#define DOWN 8u
#define FIRE 16u
#define ROTATE 32u
enum { DARK=0,PAPER=1,CYAN=2,PINK=3,PURPLE=4,GREEN=5,GOLD=6,WHITE=7,SLATE=8,PANEL=9,ROSE=10,MUTED=11,BLUE=12,TEAL=13,PLUM=14,WINE=15 };
extern uint32_t random_state;
uint32_t random32(void);
void put(int x,int y,uint8_t ch,uint8_t fg,uint8_t bg);
void text(int x,int y,const char *s,uint8_t fg,uint8_t bg);
void number(int x,int y,unsigned n,uint8_t color);
void rectangle(int x,int y,int w,int h,uint8_t ch,uint8_t fg,uint8_t bg);
void background(uint8_t color);
void snake_init(void);void snake_update(unsigned buttons,int automatic);void snake_draw(void);
void maze_init(void);void maze_update(unsigned buttons,int automatic);void maze_draw(void);
void blocks_init(void);void blocks_update(unsigned buttons,int automatic);void blocks_draw(void);
void letter_init(void);void letter_update(unsigned buttons,int automatic);void letter_draw(void);
unsigned app_score(unsigned game);unsigned app_state(unsigned game);unsigned app_x(unsigned game);unsigned app_y(unsigned game);
void game_init(unsigned game);void game_update(unsigned game,unsigned buttons,int automatic);void game_draw(unsigned game);
extern uint16_t snake_body[560],snake_length,snake_food;
extern uint8_t snake_direction,snake_state,snake_occupied[70];
extern uint8_t maze_map[651],maze_x,maze_y,maze_state;
extern uint16_t maze_steps;
extern uint8_t blocks_board[20][10],blocks_piece,blocks_rotation,blocks_next,blocks_state;
extern int blocks_x,blocks_y;
extern uint16_t blocks_score,blocks_lines;
int blocks_fits(int x,int y,unsigned piece,unsigned rotation);
unsigned blocks_clear_lines(void);
extern uint16_t letter_reveal,letter_clock;
extern uint8_t letter_open;
#endif
