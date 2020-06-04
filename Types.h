/* TYPES.H: useful type definitions */

/*
 * Copyright (c) 2002-2020, Ian Chapman (Chapmip Consultancy)
 *
 * This software is licensed under the MIT license (see LICENSE.TXT)
 *
 * See README.md for information on typical usage
 *
 */

#ifndef TYPES_H
#define TYPES_H

typedef unsigned char byte;
typedef unsigned int  word;
typedef unsigned long quad;

/* Assuming big-endian storage (as per 8051) */

#define BYTELOW(v)  (*(((byte *) (&v) + 1)))
#define BYTEHIGH(v) (*((byte *) (&v)))
#define WORDVAL(v)  (*((word *) (&v)))

#endif
