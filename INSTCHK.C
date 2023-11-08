/* simple EtherDFS install check - 5/2023 Frank Haeseler */

/* this is a small tool I use in some batch files
 * (not needed to run EtherDFS)
 *
 * there is only one option: '-b' for batch mode (quiet mode),
 * i.e. errorlevel only
 *
 * code taken from 'etherdfs.c' Copyright (C) 2017, 2018 Mateusz Viste
 */

#include "dosstruc.h" /* definitions of structures used by DOS */

#define ARGFL_QUIET 1

/* a structure used to pass and decode arguments between main() and parseargv() */
struct argstruct {
  int argc;    /* original argc */
  char **argv; /* original argv */
  unsigned char flags; /* ARGFL_QUIET */
};

/* zero out an object of l bytes */
static void zerobytes(void *obj, unsigned short l) {
  unsigned char *o = obj;
  while (l-- != 0) {
    *o = 0;
    o++;
  }
}

/* parses (and applies) command-line arguments. returns 0 on success, */
/* non-zero otherwise */
static int parseargv(struct argstruct *args) {
  int i;

  /* iterate through arguments, if any */
  for (i = 1; i < args->argc; i++) {
    char opt;

    /* is it an option? */
    if ((args->argv[i][0] == '/') || (args->argv[i][0] == '-')) {
      if (args->argv[i][1] == 0) return(-3);
      opt = args->argv[i][1];
      /* normalize the option char to lower case */
      if ((opt >= 'A') && (opt <= 'Z')) opt += ('a' - 'A');
      /* what is the option about? */
      switch (opt) {
	case 'b':        /* batchmode/quiet: this is our only valid option */
          args->flags |= ARGFL_QUIET;
          break;
        default: /* invalid parameter */
          return(-5);
      }
      continue;
    }
  }
  return(0);
}

/* scans the 2Fh interrupt for some available 'multiplex id' in the range
 * C0..FF. also checks for EtherDFS presence at the same time. returns:
 *  - the available id if found
 *  - the id of the already-present etherdfs instance
 *  - 0 if no available id found
 * presentflag set to 0 if no etherdfs found loaded, non-zero otherwise. */

static unsigned char findfreemultiplex(unsigned char *presentflag) {
  unsigned char id = 0, freeid = 0, pflag = 0;
  _asm {
    mov id, 0C0h /* start scanning at C0h */
    checkid:
    xor al, al   /* subfunction is 'installation check' (00h) */
    mov ah, id
    int 2Fh
    /* is it free? (AL == 0) */
    test al, al
    jnz notfree    /* not free - is it me perhaps? */
    mov freeid, ah /* it's free - remember it, I may use it myself soon */
    jmp checknextid
    notfree:
    /* is it me? (AL=FF + BX=4D86 CX=7E1 [MV 2017]) */
    cmp al, 0ffh
    jne checknextid
    cmp bx, 4d86h
    jne checknextid
    cmp cx, 7e1h
    jne checknextid
    /* if here, then it's me... */
    mov ah, id
    mov freeid, ah
    mov pflag, 1
    jmp gameover
    checknextid:
    /* if not me, then check next id */
    inc id
    jnz checkid /* if id is zero, then all range has been covered (C0..FF) */
    gameover:
  }
  *presentflag = pflag;
  return(freeid);
}


int main(int argc, char **argv) {
  struct argstruct args;
  unsigned char tmpflag = 0;
  unsigned char etherdfsid;

  /* parse command-line arguments */
  zerobytes(&args, sizeof(args));
  args.argc = argc;
  args.argv = argv;

  if (parseargv(&args) != 0) {
    return(1);
  }

  /* look whether or not it's ok to install a network redirector at int 2F */
  _asm {
    mov tmpflag, 0
    mov ax, 1100h
    int 2Fh
    dec ax /* if AX was set to 1 (ie. "not ok to install"), it's zero now */
    jnz goodtogo
    mov tmpflag, 1
    goodtogo:
  }
  if (tmpflag != 0) {
    #include "msg\\noredir.c"
    return(1);
  }

  /* am I loaded? */
  etherdfsid = findfreemultiplex(&tmpflag);
  if (tmpflag == 0) {    /* not loaded */
    if ((args.flags & ARGFL_QUIET) == 0)
      #include "msg\\notload1.c"
    return(1);          /* Errorlevel 1 */
  } else {              /* loaded */
    if ((args.flags & ARGFL_QUIET) == 0)
      #include "msg\\loaded.c"
    return(0);          /* Errorlevel 0 */
  }
} 

