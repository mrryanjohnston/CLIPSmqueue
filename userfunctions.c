   /*******************************************************/
   /*      "C" Language Integrated Production System      */
   /*                                                     */
   /*            CLIPS Version 6.40  07/30/16             */
   /*                                                     */
   /*                USER FUNCTIONS MODULE                */
   /*******************************************************/

/*************************************************************/
/* Purpose:                                                  */
/*                                                           */
/* Principal Programmer(s):                                  */
/*      Gary D. Riley                                        */
/*                                                           */
/* Contributing Programmer(s):                               */
/*                                                           */
/* Revision History:                                         */
/*                                                           */
/*      6.24: Created file to seperate UserFunctions and     */
/*            EnvUserFunctions from main.c.                  */
/*                                                           */
/*      6.30: Removed conditional code for unsupported       */
/*            compilers/operating systems (IBM_MCW,          */
/*            MAC_MCW, and IBM_TBC).                         */
/*                                                           */
/*            Removed use of void pointers for specific      */
/*            data structures.                               */
/*                                                           */
/*************************************************************/

/***************************************************************************/
/*                                                                         */
/* Permission is hereby granted, free of charge, to any person obtaining   */
/* a copy of this software and associated documentation files (the         */
/* "Software"), to deal in the Software without restriction, including     */
/* without limitation the rights to use, copy, modify, merge, publish,     */
/* distribute, and/or sell copies of the Software, and to permit persons   */
/* to whom the Software is furnished to do so.                             */
/*                                                                         */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS */
/* OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF              */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT   */
/* OF THIRD PARTY RIGHTS. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY  */
/* CLAIM, OR ANY SPECIAL INDIRECT OR CONSEQUENTIAL DAMAGES, OR ANY DAMAGES */
/* WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN   */
/* ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF */
/* OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.          */
/*                                                                         */
/***************************************************************************/

#define _POSIX_C_SOURCE 200809L
#define _GNU_SOURCE

#include "clips.h"
#include <errno.h>
#include <sys/stat.h>
#include <time.h>
#include <mqueue.h>

void UserFunctions(Environment *);

static void UdfSyscallError(Environment *theEnv, const char *fn, const char *what)
{
	WriteString(theEnv, STDERR, fn);
	WriteString(theEnv, STDERR, ": ");
	WriteString(theEnv, STDERR, what);
	WriteString(theEnv, STDERR, ": ");
	WriteString(theEnv, STDERR, strerror(errno));
	WriteString(theEnv, STDERR, "\n");
}

static void UdfError(Environment *theEnv, const char *fn, const char *msg)
{
	WriteString(theEnv, STDERR, fn);
	WriteString(theEnv, STDERR, ": ");
	WriteString(theEnv, STDERR, msg);
	WriteString(theEnv, STDERR, "\n");
}

static void UdfError2(Environment *theEnv, const char *fn, const char *a, const char *b)
{
	WriteString(theEnv, STDERR, fn);
	WriteString(theEnv, STDERR, ": ");
	WriteString(theEnv, STDERR, a);
	WriteString(theEnv, STDERR, b);
	WriteString(theEnv, STDERR, "\n");
}

static void UdfError3(Environment *theEnv, const char *fn, const char *a, const char *b, const char *c)
{
	WriteString(theEnv, STDERR, fn);
	WriteString(theEnv, STDERR, ": ");
	WriteString(theEnv, STDERR, a);
	WriteString(theEnv, STDERR, b);
	WriteString(theEnv, STDERR, c);
	WriteString(theEnv, STDERR, "\n");
}

static void UdfError4(Environment *theEnv, const char *fn, const char *a, const char *b, const char *c, const char *d)
{
	WriteString(theEnv, STDERR, fn);
	WriteString(theEnv, STDERR, ": ");
	WriteString(theEnv, STDERR, a);
	WriteString(theEnv, STDERR, b);
	WriteString(theEnv, STDERR, c);
	WriteString(theEnv, STDERR, d);
	WriteString(theEnv, STDERR, "\n");
}

/*********************************************************/
/* UserFunctions: Informs the expert system environment  */
/*   of any user defined functions. In the default case, */
/*   there are no user defined functions. To define      */
/*   functions, either this function must be replaced by */
/*   a function with the same name within this file, or  */
/*   this function can be deleted from this file and     */
/*   included in another file.                           */
/*********************************************************/
static bool MqSymbolToOFlag(const char *s, int *oflag)
{
	if (!s || !oflag) return false;

	/* Access mode */
	if (strcmp(s, "O_RDONLY") == 0) { *oflag |= O_RDONLY; return true; }
	if (strcmp(s, "O_WRONLY") == 0) { *oflag |= O_WRONLY; return true; }
	if (strcmp(s, "O_RDWR")   == 0) { *oflag |= O_RDWR;   return true; }

	/* Common flags */
#ifdef O_NONBLOCK
	if (strcmp(s, "O_NONBLOCK") == 0) { *oflag |= O_NONBLOCK; return true; }
#endif
#ifdef O_CREAT
	if (strcmp(s, "O_CREAT") == 0) { *oflag |= O_CREAT; return true; }
#endif
#ifdef O_EXCL
	if (strcmp(s, "O_EXCL") == 0) { *oflag |= O_EXCL; return true; }
#endif
#ifdef O_TRUNC
	if (strcmp(s, "O_TRUNC") == 0) { *oflag |= O_TRUNC; return true; }
#endif

	return false;
}

static bool MqSymbolToMode(const char *s, mode_t *mode)
{
	if (!s || !mode) return false;

#ifdef S_IRUSR
	if (strcmp(s, "S_IRUSR") == 0) { *mode |= S_IRUSR; return true; }
#endif
#ifdef S_IWUSR
	if (strcmp(s, "S_IWUSR") == 0) { *mode |= S_IWUSR; return true; }
#endif
#ifdef S_IXUSR
	if (strcmp(s, "S_IXUSR") == 0) { *mode |= S_IXUSR; return true; }
#endif
#ifdef S_IRGRP
	if (strcmp(s, "S_IRGRP") == 0) { *mode |= S_IRGRP; return true; }
#endif
#ifdef S_IWGRP
	if (strcmp(s, "S_IWGRP") == 0) { *mode |= S_IWGRP; return true; }
#endif
#ifdef S_IXGRP
	if (strcmp(s, "S_IXGRP") == 0) { *mode |= S_IXGRP; return true; }
#endif
#ifdef S_IROTH
	if (strcmp(s, "S_IROTH") == 0) { *mode |= S_IROTH; return true; }
#endif
#ifdef S_IWOTH
	if (strcmp(s, "S_IWOTH") == 0) { *mode |= S_IWOTH; return true; }
#endif
#ifdef S_IXOTH
	if (strcmp(s, "S_IXOTH") == 0) { *mode |= S_IXOTH; return true; }
#endif
#ifdef S_IRWXU
	if (strcmp(s, "S_IRWXU") == 0) { *mode |= S_IRWXU; return true; }
#endif
#ifdef S_IRWXG
	if (strcmp(s, "S_IRWXG") == 0) { *mode |= S_IRWXG; return true; }
#endif
#ifdef S_IRWXO
	if (strcmp(s, "S_IRWXO") == 0) { *mode |= S_IRWXO; return true; }
#endif

	return false;
}

// from vendor/clips/genrcfun.c
// for some reason this only comes in when COOL is not present
#if OBJECT_SYSTEM
const char *TypeName(
  Environment *theEnv,
  long long tcode)
  {
   switch (tcode)
     {
      case INTEGER_TYPE             : return(INTEGER_TYPE_NAME);
      case FLOAT_TYPE               : return(FLOAT_TYPE_NAME);
      case SYMBOL_TYPE              : return(SYMBOL_TYPE_NAME);
      case STRING_TYPE              : return(STRING_TYPE_NAME);
      case MULTIFIELD_TYPE          : return(MULTIFIELD_TYPE_NAME);
      case EXTERNAL_ADDRESS_TYPE    : return(EXTERNAL_ADDRESS_TYPE_NAME);
      case FACT_ADDRESS_TYPE        : return(FACT_ADDRESS_TYPE_NAME);
      case INSTANCE_ADDRESS_TYPE    : return(INSTANCE_ADDRESS_TYPE_NAME);
      case INSTANCE_NAME_TYPE       : return(INSTANCE_NAME_TYPE_NAME);
      case OBJECT_TYPE_CODE    : return(OBJECT_TYPE_NAME);
      case PRIMITIVE_TYPE_CODE : return(PRIMITIVE_TYPE_NAME);
      case NUMBER_TYPE_CODE    : return(NUMBER_TYPE_NAME);
      case LEXEME_TYPE_CODE    : return(LEXEME_TYPE_NAME);
      case ADDRESS_TYPE_CODE   : return(ADDRESS_TYPE_NAME);
      case INSTANCE_TYPE_CODE  : return(INSTANCE_TYPE_NAME);
      default                  : PrintErrorID(theEnv,"INSCOM",1,false);
                                 WriteString(theEnv,STDERR,"Undefined type in function 'type'.\n");
                                 SetEvaluationError(theEnv,true);
                                 return("<UNKNOWN-TYPE>");
     }
  }
#endif

static bool ParseIntFromFactSlot(Environment *theEnv, const char *fn, Deftemplate *dt, Fact *f, const char *slotName, long *attr)
{
	CLIPSValue slot;

	if (!DeftemplateSlotExistP(dt, slotName))
	{
		UdfError4(theEnv, fn, "WARNING: slot '", slotName, "' not found for deftemplate ", DeftemplateName(dt));
		return true;
	}
	FactSlotValue(theEnv, f, slotName, &slot);
	if (slot.header->type == SYMBOL_TYPE && 0 == strcmp(slot.lexemeValue->contents, "nil"))
	{
		return true;
	}
	else
	if (slot.header->type != INTEGER_TYPE)
	{
		UdfError4(theEnv, fn, "expected an INTEGER but slot '", slotName, "' contained a ", TypeName(theEnv, (long long)slot.header->type));
		return false;
	}

	*attr = (long)slot.integerValue->contents;
	return true;
}

static bool ParseIntFromInstanceSlot(Environment *theEnv, const char *fn, Defclass *dc, Instance *i, const char *slotName, long *attr)
{
	CLIPSValue slot;

	if (!SlotExistP(dc, slotName, true))
	{
		UdfError4(theEnv, fn, "WARNING: slot '", slotName, "' not found for defclass ", DefclassName(dc));
		return true;
	}
	DirectGetSlot(i, slotName, &slot);
	if (slot.header->type == SYMBOL_TYPE && 0 == strcmp(slot.lexemeValue->contents, "nil"))
	{
		return true;
	}
	else
	if (slot.header->type != INTEGER_TYPE)
	{
		UdfError4(theEnv, fn, "expected an INTEGER but slot '", slotName, "' contained a ", TypeName(theEnv, (long long)slot.header->type));
		return false;
	}

	*attr = (long)slot.integerValue->contents;
	return true;
}

static bool MqIbPutSlot(Environment *theEnv, const char *fn, InstanceBuilder *ib, const char *slotName, const char *defclassName, CLIPSValue *cv)
{
	switch (IBPutSlot(ib, slotName, cv))
	{
		case PSE_NULL_POINTER_ERROR:
		case PSE_INVALID_TARGET_ERROR:
		case PSE_TYPE_ERROR:
		case PSE_RANGE_ERROR:
		case PSE_ALLOWED_VALUES_ERROR:
		case PSE_CARDINALITY_ERROR:
		case PSE_ALLOWED_CLASSES_ERROR:
			UdfError3(theEnv, fn, "IBPutSlot(", slotName, ") failed");
			IBDispose(ib);
			return false;
		case PSE_SLOT_NOT_FOUND_ERROR:
			UdfError4(theEnv, fn, "WARNING: slot '", slotName, "' not found for defclass ", defclassName);
		case PSE_NO_ERROR:
		default:
			return true;
	}
}

static bool MqFbPutSlot(Environment *theEnv, const char *fn, FactBuilder *fb, const char *slotName, const char *deftemplateName, CLIPSValue *cv)
{
	switch (FBPutSlot(fb, slotName, cv))
	{
		case PSE_NULL_POINTER_ERROR:
		case PSE_INVALID_TARGET_ERROR:
		case PSE_TYPE_ERROR:
		case PSE_RANGE_ERROR:
		case PSE_ALLOWED_VALUES_ERROR:
		case PSE_CARDINALITY_ERROR:
		case PSE_ALLOWED_CLASSES_ERROR:
			UdfError3(theEnv, fn, "FBPutSlot(", slotName, ") failed");
			FBDispose(fb);
			return false;
		case PSE_SLOT_NOT_FOUND_ERROR:
			UdfError4(theEnv, fn, "WARNING: slot '", slotName, "' not found for deftemplate ", deftemplateName);
		case PSE_NO_ERROR:
		default:
			return true;
	}
}

static bool ParseTimespecFromValue(Environment *theEnv, const char *fn, UDFValue *val, struct timespec *ts)
{
	long long sec = 0;
	long long nsec = 0;

	if (!ts)
	{
		UdfError(theEnv, fn, "internal error: NULL timespec pointer");
		return false;
	}

	memset(ts, 0, sizeof(*ts));

	if (val->header->type == INTEGER_TYPE)
	{
		sec = (long long)val->integerValue->contents;
	}
	else
	if (val->header->type == MULTIFIELD_TYPE)
	{
		Multifield *mf = val->multifieldValue;
		if (mf->length < 2)
		{
			UdfError(theEnv, fn, "timespec multifield must have at least 2 integers: sec nsec");
			return false;
		}

		CLIPSValue *f0 = &mf->contents[0];
		CLIPSValue *f1 = &mf->contents[1];

		if (f0->header->type != INTEGER_TYPE || f1->header->type != INTEGER_TYPE)
		{
			UdfError(theEnv, fn, "timespec multifield elements must be integers");
			return false;
		}

		sec  = (long long)f0->integerValue->contents;
		nsec = (long long)f1->integerValue->contents;
	}
	else if (val->header->type == FACT_ADDRESS_TYPE)
	{
		Fact *fact = val->factValue;
		Deftemplate *deftemplate;

		deftemplate = FactDeftemplate(fact);

		if (!ParseIntFromFactSlot(theEnv, fn, deftemplate, fact, "sec", (long*)&(sec))) return false;
		if (!ParseIntFromFactSlot(theEnv, fn, deftemplate, fact, "nsec", (long*)&(nsec))) return false;
	}
	else if (val->header->type == INSTANCE_ADDRESS_TYPE)
	{
		Instance *ins = val->instanceValue;

		Defclass *defclass;

		defclass = InstanceClass(ins);

		if (!ParseIntFromInstanceSlot(theEnv, fn, defclass, ins, "sec", (long*)&(sec))) return false;
		if (!ParseIntFromInstanceSlot(theEnv, fn, defclass, ins, "nsec", (long*)&(nsec))) return false;
	}
	else
	{
		UdfError(theEnv, fn, "timespec must be multifield, fact, or instance");
		return false;
	}

	if (nsec < 0 || nsec >= 1000000000LL)
	{
		UdfError(theEnv, fn, "nsec must be in [0, 1000000000)");
		return false;
	}

	ts->tv_sec  = (time_t)sec;
	ts->tv_nsec = (long)nsec;
	return true;
}

static bool ParseOFlagsFromValue(Environment *theEnv, const char *fn, UDFValue *val, int *oflag)
{
	size_t i;

	if (val->header->type == SYMBOL_TYPE)
	{
		if (!MqSymbolToOFlag(val->lexemeValue->contents, oflag))
		{
			UdfError2(theEnv, fn, "invalid oflag symbol ", val->lexemeValue->contents);
			return false;
		}
		return true;
	}
	else if (val->header->type == INTEGER_TYPE)
	{
		*oflag |= (int)val->integerValue->contents;
		return true;
	}
	else if (val->header->type == MULTIFIELD_TYPE)
	{
		Multifield *mf = val->multifieldValue;
		for (i = 0; i < mf->length; i++)
		{
			CLIPSValue *f = &mf->contents[i];
			if (f->header->type != SYMBOL_TYPE)
			{
				UdfError(theEnv, fn, "oflag multifield must contain only symbols");
				return false;
			}
			if (!MqSymbolToOFlag(f->lexemeValue->contents, oflag))
			{
				UdfError2(theEnv, fn, "invalid oflag symbol ", f->lexemeValue->contents);
				return false;
			}
		}
		return true;
	}

	UdfError(theEnv, fn, "oflag must be symbol, integer, or multifield of symbols");
	return false;
}

static bool ParseModeFromValue(Environment *theEnv, const char *fn, UDFValue *val, mode_t *mode)
{
	size_t i;

	if (val->header->type == INTEGER_TYPE)
	{
		long long _val = val->integerValue->contents;

		if (_val < 0 || _val > 7777)
		{
			UdfError(theEnv, fn, "mode integer out of range (0-7777)");
			return false;
		}

		mode_t m = 0;
		long long tmp = _val;
		int shift = 0;

		while (tmp > 0)
		{
			int digit = (int)(tmp % 10);
			if (digit < 0 || digit > 7)
			{
				UdfError(theEnv, fn, "mode integer must be octal (digits 0-7 only)");
				return false;
			}
			m |= ((mode_t)digit & 7) << shift;
			shift += 3;
			tmp /= 10;
		}

		*mode = m;
		return true;
	}
	else if (val->header->type == SYMBOL_TYPE)
	{
		if (!MqSymbolToMode(val->lexemeValue->contents, mode))
		{
			UdfError2(theEnv, fn, "invalid mode symbol ", val->lexemeValue->contents);
			return false;
		}
		return true;
	}
	else if (val->header->type == MULTIFIELD_TYPE)
	{
		Multifield *mf = val->multifieldValue;
		for (i = 0; i < mf->length; i++)
		{
			CLIPSValue *f = &mf->contents[i];
			if (f->header->type == INTEGER_TYPE)
			{
				*mode |= (mode_t)f->integerValue->contents;
			}
			else if (f->header->type == SYMBOL_TYPE)
			{
				if (!MqSymbolToMode(f->lexemeValue->contents, mode))
				{
					UdfError2(theEnv, fn, "invalid mode symbol ", f->lexemeValue->contents);
					return false;
				}
			}
			else
			{
				UdfError(theEnv, fn, "mode multifield must contain only integers or symbols");
				return false;
			}
		}
		return true;
	}

	UdfError(theEnv, fn, "mode must be integer, symbol, or multifield");
	return false;
}

static bool ParseMqAttrFromMultifield(Environment *theEnv, const char *fn, UDFValue *val, struct mq_attr *attr)
{
	Multifield *mf;
	long v[4];
	size_t i;

	mf = val->multifieldValue;
	if (mf->length < 4)
	{
		UdfError(theEnv, fn, "WARNING: mq_attr multifield does not have at least 4 numeric values");
	}

	for (i = 0; i < mf->length; i++)
	{
		CLIPSValue *f = &mf->contents[i];
		if (f->header->type != INTEGER_TYPE)
		{
			UdfError(theEnv, fn, "mq_attr multifield elements must be integers");
			return false;
		}
		v[i] = (long)f->integerValue->contents;
	}

	if (mf->length >= 1) attr->mq_flags   = v[0];
	if (mf->length >= 2) attr->mq_maxmsg  = v[1];
	if (mf->length >= 3) attr->mq_msgsize = v[2];
	if (mf->length >= 4) attr->mq_curmsgs = v[3];

	return true;
}

static bool ParseMqAttrFromFact(Environment *theEnv, const char *fn, Fact *fact, struct mq_attr *attr)
{
	Deftemplate *deftemplate;

	deftemplate = FactDeftemplate(fact);

	return ParseIntFromFactSlot(theEnv, fn, deftemplate, fact, "flags", &(attr->mq_flags)) &&
		ParseIntFromFactSlot(theEnv, fn, deftemplate, fact, "maxmsg", &(attr->mq_maxmsg)) &&
		ParseIntFromFactSlot(theEnv, fn, deftemplate, fact, "msgsize", &(attr->mq_msgsize)) &&
		ParseIntFromFactSlot(theEnv, fn, deftemplate, fact, "curmsgs", &(attr->mq_curmsgs));
}

static bool ParseMqAttrFromInstance(Environment *theEnv, const char *fn, Instance *ins, struct mq_attr *attr)
{
	Defclass *defclass;

	defclass = InstanceClass(ins);

	return ParseIntFromInstanceSlot(theEnv, fn, defclass, ins, "flags", &(attr->mq_flags)) &&
		ParseIntFromInstanceSlot(theEnv, fn, defclass, ins, "maxmsg", &(attr->mq_maxmsg)) &&
		ParseIntFromInstanceSlot(theEnv, fn, defclass, ins, "msgsize", &(attr->mq_msgsize)) &&
		ParseIntFromInstanceSlot(theEnv, fn, defclass, ins, "curmsgs", &(attr->mq_curmsgs));
}

static bool ParseMqAttrFromValue(Environment *theEnv, const char *fn, UDFValue *val, struct mq_attr *attr)
{
	if (val->header->type == MULTIFIELD_TYPE)
	{
		return ParseMqAttrFromMultifield(theEnv, fn, val, attr);
	}
	else if (val->header->type == FACT_ADDRESS_TYPE)
	{
		return ParseMqAttrFromFact(theEnv, fn, val->factValue, attr);
	}
	else if (val->header->type == INSTANCE_ADDRESS_TYPE)
	{
		return ParseMqAttrFromInstance(theEnv, fn, val->instanceValue, attr);
	}

	UdfError(theEnv, fn, "mq_attr must be multifield, fact, or instance");
	return false;
}

void MqOpenFunction(Environment *theEnv, UDFContext *context, UDFValue *returnValue)
{
	const char *fn = "mq-open";
	UDFValue arg;
	const char *name;
	int oflag = 0;
	mode_t mode = 0;
	bool haveMode = false;
	struct mq_attr attr;
	struct mq_attr *attrPtr = NULL;
	bool haveAttr = false;
	mqd_t mqdes;

	errno = 0;

	returnValue->lexemeValue = FalseSymbol(theEnv);

	if (!UDFFirstArgument(context, LEXEME_BITS, &arg))
	{
		return;
	}

	name = arg.lexemeValue->contents;

	if (!UDFNextArgument(context, MULTIFIELD_BIT | SYMBOL_BIT | INTEGER_BIT, &arg))
	{
		return;
	}

	if (!ParseOFlagsFromValue(theEnv, fn, &arg, &oflag))
	{
		return;
	}

	if (UDFHasNextArgument(context))
	{
		if (!UDFNextArgument(context, MULTIFIELD_BIT | SYMBOL_BIT | INTEGER_BIT, &arg))
		{
			return;
		}

		if (!ParseModeFromValue(theEnv, fn, &arg, &mode))
		{
			return;
		}

		haveMode = true;
	}

	if (UDFHasNextArgument(context))
	{
		if (!UDFNextArgument(context, MULTIFIELD_BIT | FACT_ADDRESS_BIT | INSTANCE_ADDRESS_BIT, &arg))
		{
			return;
		}

		memset(&attr, 0, sizeof(attr));

		if (!ParseMqAttrFromValue(theEnv, fn, &arg, &attr))
		{
			return;
		}

		attrPtr = &attr;
		haveAttr = true;
	}

	if ((oflag & O_CREAT) && !haveMode)
	{
		UdfError(theEnv, fn, "oflag includes O_CREAT but no mode argument was supplied");
		return;
	}

	if (!haveMode)
	{
		mode = 0;
	}

	if (!haveAttr)
	{
		attrPtr = NULL;
	}

	mqdes = mq_open(name, oflag, mode, attrPtr);

	if (mqdes == (mqd_t)-1)
	{
		UdfSyscallError(theEnv, fn, "mq_open failed");
		return;
	}

	returnValue->integerValue = CreateInteger(theEnv, (long long)mqdes);
}

static void MqCloseFunction(Environment *theEnv, UDFContext *context, UDFValue *returnValue)
{
	const char *fn = "mq-close";
	UDFValue arg;
	mqd_t mqdes;

	returnValue->lexemeValue = FalseSymbol(theEnv);

	if (!UDFFirstArgument(context, INTEGER_BIT, &arg))
	{
		return;
	}

	mqdes = (mqd_t)arg.integerValue->contents;

	errno = 0;
	if (mq_close(mqdes) == -1)
	{
		UdfSyscallError(theEnv, fn, "mq_close failed");
		return;
	}

	returnValue->lexemeValue = TrueSymbol(theEnv);
}

static void MqUnlinkFunction(Environment *theEnv, UDFContext *context, UDFValue *returnValue)
{
	const char *fn = "mq-unlink";
	UDFValue arg;
	const char *name;

	returnValue->lexemeValue = FalseSymbol(theEnv);

	if (!UDFFirstArgument(context, LEXEME_BITS, &arg))
	{
		return;
	}

	name = arg.lexemeValue->contents;

	errno = 0;
	if (mq_unlink(name) == -1)
	{
		UdfSyscallError(theEnv, fn, "mq_unlink failed");
		return;
	}

	returnValue->lexemeValue = TrueSymbol(theEnv);
}

static void MqNotifyFunction(Environment *theEnv, UDFContext *context, UDFValue *returnValue)
{
	UDFValue arg;
	mqd_t mqdes;
	struct sigevent sev;
	struct sigevent *sevPtr = NULL;
	const char *fn = "mq-notify";

	returnValue->lexemeValue = FalseSymbol(theEnv);

	if (!UDFFirstArgument(context, INTEGER_BIT, &arg))
	{
		UdfError(theEnv, fn, "First argument must be an integer (mqd_t)\n");
		return;
	}
	mqdes = (mqd_t)arg.integerValue->contents;

	if (UDFHasNextArgument(context))
	{
		if (!UDFNextArgument(context, MULTIFIELD_BIT | FACT_ADDRESS_BIT | INSTANCE_ADDRESS_BIT, &arg))
		{
			WriteString(theEnv, STDERR, "mq-notify: Second argument must be a multifield containing 3 integers, a fact, or an instance\n");
			return;
		}

		memset(&sev, 0, sizeof(sev));

		if (arg.header->type == MULTIFIELD_TYPE)
		{
			Multifield *mf = arg.multifieldValue;
			if (mf->length < 3)
			{
				WriteString(theEnv, STDERR, "mq-notify: sigevent multifield must have at least 3 integers\n");
				return;
			}

			CLIPSValue *f0 = &mf->contents[0];
			CLIPSValue *f1 = &mf->contents[1];
			CLIPSValue *f2 = &mf->contents[2];

			if (f0->header->type != INTEGER_TYPE || f1->header->type != INTEGER_TYPE || f2->header->type != INTEGER_TYPE)
			{
				WriteString(theEnv, STDERR, "mq-notify: sigevent must contain integer notify/signo/value\n");
				return;
			}

			sev.sigev_notify          = (int)f0->integerValue->contents;
			sev.sigev_signo           = (int)f1->integerValue->contents;
			sev.sigev_value.sival_int = (int)f2->integerValue->contents;
			sevPtr = &sev;
		}
		else if (arg.header->type == FACT_ADDRESS_TYPE)
		{
			Fact *fact = arg.factValue;
			Deftemplate *deftemplate;

			deftemplate = FactDeftemplate(fact);

			if (!ParseIntFromFactSlot(theEnv, fn, deftemplate, fact, "notify", (long*)&(sev.sigev_notify))) return;
			if (!ParseIntFromFactSlot(theEnv, fn, deftemplate, fact, "signo", (long*)&(sev.sigev_signo))) return;
			if (!ParseIntFromFactSlot(theEnv, fn, deftemplate, fact, "value", (long*)&(sev.sigev_value.sival_int))) return;

			sevPtr = &sev;
		}
		else if (arg.header->type == INSTANCE_ADDRESS_TYPE)
		{
			Instance *ins = arg.instanceValue;
			Defclass *defclass;

			defclass = InstanceClass(ins);

			if (!ParseIntFromInstanceSlot(theEnv, fn, defclass, ins, "notify", (long*)&(sev.sigev_notify))) return;
			if (!ParseIntFromInstanceSlot(theEnv, fn, defclass, ins, "signo", (long*)&(sev.sigev_signo))) return;
			if (!ParseIntFromInstanceSlot(theEnv, fn, defclass, ins, "value", (long*)&(sev.sigev_value.sival_int))) return;

			sevPtr = &sev;
		}
	}

	errno = 0;
	if (mq_notify(mqdes, sevPtr) == -1)
	{
		UdfSyscallError(theEnv, fn, "mq_notify failed");
		return;
	}

	returnValue->lexemeValue = TrueSymbol(theEnv);
}

typedef enum
{
	MQ_RTYPE_UNKNOWN = -1,
	MQ_RTYPE_STRING,
	MQ_RTYPE_SYMBOL,
	MQ_RTYPE_MULTIFIELD,
	MQ_RTYPE_FACT,
	MQ_RTYPE_INSTANCE
} MQReturnType;

static void MQ_BuildReturnSymbol(Environment *theEnv, UDFValue *returnValue, const char *buf)
{
	returnValue->lexemeValue = CreateSymbol(theEnv, buf);
}

static void MQ_BuildReturnString(Environment *theEnv, UDFValue *returnValue, const char *buf)
{
	returnValue->lexemeValue = CreateString(theEnv, buf);
}

static void MQ_BuildReturnMultifield(Environment *theEnv, UDFValue *returnValue, const char *buf, unsigned int priority)
{
	MultifieldBuilder *mb = CreateMultifieldBuilder(theEnv, 2);

	MBAppendString(mb, buf);
	MBAppendInteger(mb, priority);

	returnValue->multifieldValue = MBCreate(mb);
	MBDispose(mb);
}

static void MQ_BuildReturnFact(Environment *theEnv, UDFValue *returnValue, const char *buf, unsigned int priority, const char *deftemplateName)
{
	CLIPSValue cv;
	FactBuilder *fb;

	returnValue->lexemeValue = FalseSymbol(theEnv);

	if (NULL == deftemplateName)
	{
		deftemplateName = "mq-message";
	}
	fb = CreateFactBuilder(theEnv, deftemplateName);
	if (fb == NULL)
	{
		UdfError3(theEnv, "mq-receive", "could not create FactBuilder for '", deftemplateName, "'");
		return;
	}

	cv.lexemeValue = CreateString(theEnv, buf);
	if (!MqFbPutSlot(theEnv, "mq-receive", fb, "data", deftemplateName, &cv)) return;
	cv.integerValue = CreateInteger(theEnv, priority);
	if (!MqFbPutSlot(theEnv, "mq-receive", fb, "priority", deftemplateName, &cv)) return;

	Fact *f = FBAssert(fb);
	FBDispose(fb);

	if (f == NULL)
	{
		UdfError3(theEnv, "mq-receive", "failed to assert'", deftemplateName, "' fact");
		return;
	}

	returnValue->factValue = f;
}

static void MQ_BuildReturnInstance(Environment *theEnv, UDFValue *returnValue, const char *buf, unsigned int priority, const char *instanceName, const char *defclassName)
{
	CLIPSValue cv;
	InstanceBuilder *ib;

	returnValue->lexemeValue = FalseSymbol(theEnv);

	if (NULL == defclassName)
	{
		defclassName = "MQ-MESSAGE";
	}
	ib = CreateInstanceBuilder(theEnv, defclassName);
	if (ib == NULL)
	{
		UdfError3(theEnv, "mq-receive", " could not create InstanceBuilder for '", defclassName, "'");
		return;
	}

	cv.lexemeValue = CreateString(theEnv, buf);
	if (!MqIbPutSlot(theEnv, "mq-receive", ib, "data", defclassName, &cv)) return;
	cv.integerValue = CreateInteger(theEnv, priority);
	if (!MqIbPutSlot(theEnv, "mq-receive", ib, "priority", defclassName, &cv)) return;

	Instance *ins = IBMake(ib, instanceName);
	IBDispose(ib);

	if (ins == NULL)
	{
		UdfError3(theEnv, "mq-receive", "failed to create '", defclassName, "' instance");
		return;
	}

	returnValue->instanceValue = ins;
}

static bool MQ_ParseRTypeSymbol(Environment *theEnv, const char *fn, const char *sym, MQReturnType *rtypeOut)
{
	if (!rtypeOut) return false;

	if (strcmp(sym, "string") == 0) { *rtypeOut = MQ_RTYPE_STRING; return true; }
	if (strcmp(sym, "symbol") == 0) { *rtypeOut = MQ_RTYPE_SYMBOL; return true; }
	if (strcmp(sym, "multifield") == 0) { *rtypeOut = MQ_RTYPE_MULTIFIELD; return true; }
	if (strcmp(sym, "fact")      == 0) { *rtypeOut = MQ_RTYPE_FACT;       return true; }
	if (strcmp(sym, "instance")  == 0) { *rtypeOut = MQ_RTYPE_INSTANCE;   return true; }

	return false;
}

void MqReceiveFunction(Environment *theEnv, UDFContext *context, UDFValue *returnValue)
{
	UDFValue arg;
	unsigned int argCount = UDFArgumentCount(context);
	const char *fn = "mq-receive";

	mqd_t mqd;
	size_t buflen = 0;
	bool haveBuflen = false;

	struct timespec ts;
	struct timespec *tsPtr = NULL;

	MQReturnType rtype = MQ_RTYPE_UNKNOWN;
	const char *instanceName = NULL, *deftemplateName = NULL, *defclassName = NULL;

	returnValue->value = FalseSymbol(theEnv);

	if (!UDFFirstArgument(context, INTEGER_BIT, &arg))
	{
		WriteString(theEnv, STDERR, "mq-receive: First argument must be an INTEGER (mqd_t)\n");
		return;
	}
	mqd = (mqd_t) arg.integerValue->contents;

	UDFValue a2, a3, a4, a5, a6, a7;

	if (argCount >= 2)
	{
		if (!UDFNthArgument(context, 2, ANY_TYPE_BITS, &a2))
		{
			return;
		}

		if (a2.header->type == INTEGER_TYPE)
		{
			buflen = (size_t) a2.integerValue->contents;
			haveBuflen = true;
		}
		else if (a2.header->type == SYMBOL_TYPE)
		{
			const char *sym2 = a2.lexemeValue->contents;

			if (!MQ_ParseRTypeSymbol(theEnv, fn, sym2, &rtype))
			{
				if (!ParseTimespecFromValue(theEnv, fn, &a2, &ts))
				{
					return;
				}
				tsPtr = &ts;
			}
		}
		else
		{
			if (!ParseTimespecFromValue(theEnv, fn, &a2, &ts))
			{
				return;
			}
			tsPtr = &ts;
		}
	}

	if (argCount >= 3)
	{
		if (!UDFNthArgument(context, 3, ANY_TYPE_BITS, &a3))
		{
			return;
		}

		if (a3.header->type == SYMBOL_TYPE)
		{
			if (rtype == MQ_RTYPE_UNKNOWN)
			{
				const char *sym3 = a3.lexemeValue->contents;
				if (!MQ_ParseRTypeSymbol(theEnv, fn, sym3, &rtype))
				{
					if (!ParseTimespecFromValue(theEnv, fn, &a3, &ts))
					{
						return;
					}
					tsPtr = &ts;
				}
			}
			else if (rtype == MQ_RTYPE_STRING || rtype == MQ_RTYPE_SYMBOL || rtype == MQ_RTYPE_MULTIFIELD)
			{
				WriteString(theEnv, STDERR, "mq-receive: no other arguments may be sent after declaring multifield, symbol, or string return types\n");
				return;
			}
			else if (rtype == MQ_RTYPE_FACT)
			{
				if (NULL == FindDeftemplate(theEnv, a3.lexemeValue->contents))
				{
					UdfError3(theEnv, fn, "could not find deftemplate '", a3.lexemeValue->contents, "'");
					return;
				}
				else
				{
					deftemplateName = a3.lexemeValue->contents;
				}
			}
			else if (rtype == MQ_RTYPE_INSTANCE)
			{
				if (NULL == FindDefclass(theEnv, a3.lexemeValue->contents))
				{
					instanceName = a3.lexemeValue->contents;
				}
				else
				{
					defclassName = a3.lexemeValue->contents;
				}
			}
		}
		else if (tsPtr == NULL)
		{
			if (!ParseTimespecFromValue(theEnv, fn, &a3, &ts))
			{
				return;
			}
			tsPtr = &ts;
		}
	}

	if (argCount >= 4)
	{
		if (!UDFNthArgument(context, 4, ANY_TYPE_BITS, &a4))
		{
			return;
		}

		if (a4.header->type == SYMBOL_TYPE)
		{
			if (rtype == MQ_RTYPE_UNKNOWN)
			{
				const char *sym4 = a4.lexemeValue->contents;
				if (!MQ_ParseRTypeSymbol(theEnv, fn, sym4, &rtype))
				{
					if (!ParseTimespecFromValue(theEnv, fn, &a4, &ts))
					{
						return;
					}
					tsPtr = &ts;
				}
			}
			else if (rtype == MQ_RTYPE_STRING || rtype == MQ_RTYPE_SYMBOL || rtype == MQ_RTYPE_MULTIFIELD)
			{
				WriteString(theEnv, STDERR, "mq-receive: no other arguments may be sent after declaring multifield or string return types\n");
				return;
			}
			else if (rtype == MQ_RTYPE_FACT)
			{
				if (NULL != deftemplateName)
				{
					UdfError3(theEnv, fn, "already received deftemplate name ", deftemplateName, "; cannot receive arguments after this");
					return;
				}
				else
				if (NULL == FindDeftemplate(theEnv, a4.lexemeValue->contents))
				{
					UdfError3(theEnv, fn, "could not find deftemplate '", a4.lexemeValue->contents, "'");
					return;
				}
				else
				{
					deftemplateName = a4.lexemeValue->contents;
				}
			}
			else if (rtype == MQ_RTYPE_INSTANCE)
			{
				if (defclassName != NULL)
				{
					instanceName = a4.lexemeValue->contents;
				}
				else
				if (NULL != FindDefclass(theEnv, a4.lexemeValue->contents))
				{
					defclassName = a4.lexemeValue->contents;
				}
				else
				{
					instanceName = a4.lexemeValue->contents;
				}
			}
		}
		else if (tsPtr == NULL)
		{
			if (!ParseTimespecFromValue(theEnv, fn, &a3, &ts))
			{
				return;
			}
			tsPtr = &ts;
		}
		else
		{
			WriteString(theEnv, STDERR, "mq-receive: unexpected 4th argument\n");
			return;
		}
	}

	if (argCount >= 5)
	{
		if (!UDFNthArgument(context, 5, ANY_TYPE_BITS, &a5))
		{
			return;
		}
		if (a5.header->type == SYMBOL_TYPE)
		{
			if (rtype == MQ_RTYPE_UNKNOWN)
			{
				const char *sym5 = a5.lexemeValue->contents;
				if (!MQ_ParseRTypeSymbol(theEnv, fn, sym5, &rtype))
				{
					WriteString(theEnv, STDERR, "mq-receive: invalid rtype symbol\n");
					return;
				}
			}
			else
			if (rtype == MQ_RTYPE_FACT)
			{
				if (NULL != deftemplateName)
				{
					UdfError3(theEnv, fn, "already received deftemplate name ", deftemplateName, "; cannot receive arguments after this");
					return;
				}
				else
				if (NULL == FindDeftemplate(theEnv, a5.lexemeValue->contents))
				{
					UdfError3(theEnv, fn, "could not find deftemplate '", a5.lexemeValue->contents, "'");
					return;
				}
				else
				{
					deftemplateName = a5.lexemeValue->contents;
				}
			}
			else if (rtype == MQ_RTYPE_INSTANCE)
			{
				if (defclassName != NULL)
				{
					instanceName = a5.lexemeValue->contents;
				}
				else
				if (NULL != FindDefclass(theEnv, a5.lexemeValue->contents))
				{
					defclassName = a5.lexemeValue->contents;
				}
				else
				{
					instanceName = a5.lexemeValue->contents;
				}
			}
		}
		else
		{
			WriteString(theEnv, STDERR, "mq-receive: too many arguments\n");
			return;
		}
	}

	if (argCount == 6)
	{
		if (!UDFNthArgument(context, 6, SYMBOL_BIT, &a6))
		{
			return;
		}
		if (a6.header->type == SYMBOL_TYPE)
		{
			if (rtype == MQ_RTYPE_INSTANCE)
			{
				if (defclassName != NULL)
				{
					instanceName = a6.lexemeValue->contents;
				}
				else
				if (NULL != FindDefclass(theEnv, a6.lexemeValue->contents))
				{
					defclassName = a6.lexemeValue->contents;
				}
				else
				{
					instanceName = a6.lexemeValue->contents;
				}
			}
		}
	}

	if (argCount == 7)
	{
		if (!UDFNthArgument(context, 7, SYMBOL_BIT, &a7))
		{
			return;
		}
		if (a7.header->type == SYMBOL_TYPE)
		{
			if (rtype == MQ_RTYPE_INSTANCE)
			{
				if (defclassName != NULL)
				{
					instanceName = a7.lexemeValue->contents;
				}
				else
				if (NULL != FindDefclass(theEnv, a7.lexemeValue->contents))
				{
					defclassName = a7.lexemeValue->contents;
				}
				else
				{
					instanceName = a7.lexemeValue->contents;
				}
			}
		}
	}

	if (rtype == MQ_RTYPE_UNKNOWN)
	{
		rtype = MQ_RTYPE_STRING;
	}

	if (!haveBuflen)
	{
		struct mq_attr attr;
		if (mq_getattr(mqd, &attr) == -1)
		{
			UdfSyscallError(theEnv, fn, "mq_getattr failed");
			return;
		}
		buflen = (size_t) attr.mq_msgsize;
	}

	char *buf = (char *) genalloc(theEnv, buflen + 1);
	if (buf == NULL)
	{
		WriteString(theEnv, STDERR, "mq-receive: genalloc failed\n");
		return;
	}

	unsigned int priority = 0;
	ssize_t n;

	errno = 0;
	if (tsPtr == NULL)
	{
		n = mq_receive(mqd, buf, buflen, &priority);
	}
	else
	{
		n = mq_timedreceive(mqd, buf, buflen, &priority, tsPtr);
	}

	if (n == -1)
	{
		WriteString(theEnv, STDERR, "mq-receive: ");
		if (tsPtr == NULL)
		{
			UdfSyscallError(theEnv, fn, "mq_receive failed");
		}
		else
		{
			UdfSyscallError(theEnv, fn, "mq_timedreceive failed");
		}

		genfree(theEnv, buf, buflen + 1);
		return;
	}

	buf[n] = '\0';

	switch (rtype)
	{
		case MQ_RTYPE_SYMBOL:
			MQ_BuildReturnSymbol(theEnv, returnValue, buf);
			break;

		case MQ_RTYPE_STRING:
			MQ_BuildReturnString(theEnv, returnValue, buf);
			break;

		case MQ_RTYPE_MULTIFIELD:
			MQ_BuildReturnMultifield(theEnv, returnValue, buf, priority);
			break;

		case MQ_RTYPE_FACT:
			MQ_BuildReturnFact(theEnv, returnValue, buf, priority, deftemplateName);
			break;

		case MQ_RTYPE_INSTANCE:
			MQ_BuildReturnInstance(theEnv, returnValue, buf, priority, instanceName, defclassName);
			break;
	}

	genfree(theEnv, buf, buflen + 1);
}

static void MqSendFunction(Environment *theEnv, UDFContext *context, UDFValue *returnValue)
{
	const char *fn = "mq-send";
	UDFValue arg;
	mqd_t mqdes;
	const char *msg = NULL;
	size_t msgLen = 0;
	unsigned int priority = 0;
	bool havePrio = false;
	bool haveLen  = false;
	struct timespec ts;
	struct timespec *timeoutPtr = NULL;

	returnValue->lexemeValue = FalseSymbol(theEnv);

	if (!UDFFirstArgument(context, INTEGER_BIT, &arg))
	{
		return;
	}
	mqdes = (mqd_t)arg.integerValue->contents;

	if (!UDFNextArgument(context, LEXEME_BITS | MULTIFIELD_BIT | FACT_ADDRESS_BIT | INSTANCE_ADDRESS_BIT, &arg))
	{
		UdfError(theEnv, fn, "Second argument must be a lexeme, multifield, fact, or instance");
		return;
	}

	if (arg.header->type == STRING_TYPE || arg.header->type == SYMBOL_TYPE)
	{
		msg = arg.lexemeValue->contents;
		priority = 0;
	}
	else
	if (arg.header->type == MULTIFIELD_TYPE)
	{
		Multifield *mf = arg.multifieldValue;

		if (mf->length < 1)
		{
			UdfError(theEnv, fn, "message multifield must have at least 1 element (data)");
			return;
		}

		CLIPSValue *f0 = &mf->contents[0];

		if (f0->header->type != STRING_TYPE && f0->header->type != SYMBOL_TYPE)
		{
			UdfError(theEnv, fn, "first element of message multifield must be string/symbol");
			return;
		}

		msg = f0->lexemeValue->contents;

		if (mf->length >= 2)
		{
			CLIPSValue *f1 = &mf->contents[1];
			if (f1->header->type != INTEGER_TYPE)
			{
				UdfError(theEnv, fn, "second element of message multifield must be integer priority");
				return;
			}
			priority = (unsigned int)f1->integerValue->contents;
			havePrio = true;
		}
	}
	else if (arg.header->type == FACT_ADDRESS_TYPE)
	{
		Fact *fact = arg.factValue;
		CLIPSValue slot;
		Deftemplate *deftemplate;

		deftemplate = FactDeftemplate(fact);

		if (!DeftemplateSlotExistP(deftemplate, "data"))
		{
			UdfError3(theEnv, fn, "Deftemplate ", DeftemplateName(deftemplate), " does not have slot 'data'");
			return;
		}
		FactSlotValue(theEnv, fact, "data", &slot);
		if (slot.header->type != STRING_TYPE && slot.header->type != SYMBOL_TYPE)
		{
			UdfError(theEnv, fn, "slot 'data' must be string/symbol");
			return;
		}
		msg = slot.lexemeValue->contents;

		if (!DeftemplateSlotExistP(deftemplate, "priority"))
		{
			UdfError3(theEnv, fn, "Deftemplate ", DeftemplateName(deftemplate), " does not have slot 'priority'");
			return;
		}
		FactSlotValue(theEnv, fact, "priority", &slot);
		if (slot.header->type == INTEGER_TYPE)
		{
			priority = (unsigned int)slot.integerValue->contents;
			havePrio = true;
		}
	}
	else if (arg.header->type == INSTANCE_ADDRESS_TYPE)
	{
		Instance *ins = arg.instanceValue;
		CLIPSValue slot;

		Defclass *defclass;

		defclass = InstanceClass(ins);

		if (!SlotExistP(defclass, "data", true))
		{
			UdfError3(theEnv, fn, "Defclass ", DefclassName(defclass), " does not have slot 'data'");
			return;
		}
		DirectGetSlot(ins, "data", &slot);
		if (slot.header->type != STRING_TYPE && slot.header->type != SYMBOL_TYPE)
		{
			UdfError(theEnv, fn, "slot 'data' must be string/symbol"); 
			return;
		}
		msg = slot.lexemeValue->contents;

		if (!SlotExistP(defclass, "priority", true))
		{
			UdfError3(theEnv, fn, "Defclass ", DefclassName(defclass), " does not have slot 'priority'");
			return;
		}
		DirectGetSlot(ins, "priority", &slot);
		if (slot.header->type == INTEGER_TYPE)
		{
			priority = (unsigned int)slot.integerValue->contents;
			havePrio = true;
		}
	}

	if (msg == NULL)
	{
		UdfError(theEnv, fn, "unable to extract message data from descriptor");
		return;
	}

	if (UDFHasNextArgument(context))
	{
		if (!UDFNextArgument(context, INTEGER_BIT | MULTIFIELD_BIT | FACT_ADDRESS_BIT | INSTANCE_ADDRESS_BIT, &arg))
		{
			UdfError(theEnv, fn, "Third argument (length or timespec) must be an integer, multifield, fact, or instance");
			return;
		}
		if (arg.header->type == INTEGER_TYPE)
		{
			if (arg.integerValue->contents < 0)
			{
				UdfError(theEnv, fn, "length must be non-negative");
				return;
			}
			msgLen = (size_t)arg.integerValue->contents;
			haveLen = true;
			if (UDFHasNextArgument(context))
			{
				if (!UDFNextArgument(context, MULTIFIELD_BIT | FACT_ADDRESS_BIT | INSTANCE_ADDRESS_BIT, &arg))
				{
					UdfError(theEnv, fn, "Fourth argument (timespec) must be a multifield, fact, or instance");
					return;
				}
				else
				if (!ParseTimespecFromValue(theEnv, fn, &arg, &ts))
				{
					return;
				}
				else
				{
					timeoutPtr = &ts;
				}
			}
		}
		else
		if (!ParseTimespecFromValue(theEnv, fn, &arg, &ts))
		{
			return;
		}
		else
		{
			timeoutPtr = &ts;
		}
	}

	if (!haveLen)
	{
		msgLen = strlen(msg);
	}

	if (!havePrio)
	{
		priority = 0;
	}

	errno = 0;
	if (timeoutPtr != NULL)
	{
		if (mq_timedsend(mqdes, msg, msgLen, priority, timeoutPtr) == -1)
		{
			UdfSyscallError(theEnv, fn, "mq_timedsend failed");
			return;
		}
	}
	else
	{
		if (mq_send(mqdes, msg, msgLen, priority) == -1)
		{
			UdfSyscallError(theEnv, fn, "mq_send failed");
			return;
		}
	}

	returnValue->lexemeValue = TrueSymbol(theEnv);
}

static bool MQ_BuildMqAttrReturn(
    Environment *theEnv, const char *fn, UDFValue *returnValue,
    const struct mq_attr *a, const char *rtype, const char *name)
{
	CLIPSValue cv;
	if (strcmp(rtype, "fact") == 0)
	{
		Deftemplate *dt = FindDeftemplate(theEnv, name);
		if (!dt)
		{
			UdfError3(theEnv, fn, "deftemplate '", name, "' not found");
			return false;
		}

		FactBuilder *fb = CreateFactBuilder(theEnv, name);
		if (!fb)
		{
			UdfError3(theEnv, fn, "CreateFactBuilder(", name, ") failed");
			return false;
		}

		cv.integerValue = CreateInteger(theEnv, a->mq_flags);
		if (!MqFbPutSlot(theEnv, fn, fb, "flags",   name, &cv))   { FBDispose(fb); return false; }
		cv.integerValue = CreateInteger(theEnv, a->mq_maxmsg);
		if (!MqFbPutSlot(theEnv, fn, fb, "maxmsg",  name, &cv))  { FBDispose(fb); return false; }
		cv.integerValue = CreateInteger(theEnv, a->mq_msgsize);
		if (!MqFbPutSlot(theEnv, fn, fb, "msgsize", name, &cv)) { FBDispose(fb); return false; }
		cv.integerValue = CreateInteger(theEnv, a->mq_curmsgs);
		if (!MqFbPutSlot(theEnv, fn, fb, "curmsgs", name, &cv)) { FBDispose(fb); return false; }

		Fact *fact = FBAssert(fb);
		FBDispose(fb);

		if (!fact)
		{
			UdfError3(theEnv, fn, "FBAssert(", name, ") failed");
			return false;
		}

		returnValue->factValue = fact;
		return true;
	}

	if (strcmp(rtype, "instance") == 0)
	{
		Defclass *dc = FindDefclass(theEnv, name);
		if (!dc)
		{
			UdfError3(theEnv, fn, "defclass '", name, "' not found");
			return false;
		}

		InstanceBuilder *ib = CreateInstanceBuilder(theEnv, name);
		if (!ib)
		{
			UdfError3(theEnv, fn, "CreateInstanceBuilder(", name, ") failed");
			return false;
		}

		cv.integerValue = CreateInteger(theEnv, a->mq_flags);
		if (!MqIbPutSlot(theEnv, fn, ib, "flags",   name, &cv))   return false;
		cv.integerValue = CreateInteger(theEnv, a->mq_maxmsg);
		if (!MqIbPutSlot(theEnv, fn, ib, "maxmsg",  name, &cv))  return false;
		cv.integerValue = CreateInteger(theEnv, a->mq_msgsize);
		if (!MqIbPutSlot(theEnv, fn, ib, "msgsize", name, &cv)) return false;
		cv.integerValue = CreateInteger(theEnv, a->mq_curmsgs);
		if (!MqIbPutSlot(theEnv, fn, ib, "curmsgs", name, &cv)) return false;

		Instance *instance = IBMake(ib, NULL);
		IBDispose(ib);

		if (!instance)
		{
			UdfError3(theEnv, fn, "IBMake(", name, ") failed");
			return false;
		}

		returnValue->instanceValue = instance;
		return true;
	}

	MultifieldBuilder *mb = CreateMultifieldBuilder(theEnv, 4);
	if (!mb)
	{
		UdfError(theEnv, fn, "CreateMultifieldBuilder failed");
		return false;
	}

	MBAppendInteger(mb, (long long)a->mq_flags);
	MBAppendInteger(mb, (long long)a->mq_maxmsg);
	MBAppendInteger(mb, (long long)a->mq_msgsize);
	MBAppendInteger(mb, (long long)a->mq_curmsgs);

	returnValue->multifieldValue = MBCreate(mb);
	MBDispose(mb);
	return true;
}

static void MqGetattrFunction(Environment *theEnv, UDFContext *context, UDFValue *returnValue)
{
	const char *fn = "mq-getattr";
	UDFValue arg;
	mqd_t mqdes;
	struct mq_attr attr;
	const char *rtype = "multifield";
	const char *name = "mq-attr";

	returnValue->lexemeValue = FalseSymbol(theEnv);

	if (!UDFFirstArgument(context, INTEGER_BIT, &arg))
	{
		return;
	}
	mqdes = (mqd_t)arg.integerValue->contents;

	if (UDFHasNextArgument(context))
	{
		if (!UDFNextArgument(context, LEXEME_BITS, &arg))
		{
			UdfError(theEnv, fn, "Second argument must be a symbol: fact, instance, or multifield");
			return;
		}
		rtype = arg.lexemeValue->contents;
		if (strcmp(rtype, "instance") == 0)
		{
			name = "MQ-ATTR";
		}
	}

	if (UDFHasNextArgument(context))
	{
		if (strcmp(rtype, "multifield") == 0)
		{
			UdfError(theEnv, fn, "Third argument may only be provided when rtype is fact or instance");
			return;
		}
		else
		if (!UDFNextArgument(context, LEXEME_BITS, &arg))
		{
			WriteString(theEnv, STDERR, fn);
			WriteString(theEnv, STDERR, ": Third argument must be a def");
			if (strcmp(rtype, "fact") == 0)
			{
				WriteString(theEnv, STDERR, "template");
			}
			else
			if (strcmp(rtype, "instance") == 0)
			{
				WriteString(theEnv, STDERR, "class");
			}
			WriteString(theEnv, STDERR, " name\n");
			return;
		}
		name = arg.lexemeValue->contents;
	}

	errno = 0;
	if (mq_getattr(mqdes, &attr) == -1)
	{
		UdfSyscallError(theEnv, fn, "mq_getattr failed");
		return;
	}

	MQ_BuildMqAttrReturn(theEnv, fn, returnValue, &attr, rtype, name);
}

static void MqSetattrFunction(Environment *theEnv, UDFContext *context, UDFValue *returnValue)
{
	const char *fn = "mq-setattr";
	UDFValue arg;
	mqd_t mqdes;
	struct mq_attr newattr;
	struct mq_attr oldattr;
	const char *rtype = "multifield";
	const char *name = "mq-attr";

	returnValue->lexemeValue = FalseSymbol(theEnv);

	if (!UDFFirstArgument(context, INTEGER_BIT, &arg))
	{
		UdfError(theEnv, fn, "First argument must be an INTEGER (mqd_t)");
		return;
	}
	mqdes = (mqd_t)arg.integerValue->contents;

	if (!UDFNextArgument(context, MULTIFIELD_BIT | FACT_ADDRESS_BIT | INSTANCE_ADDRESS_BIT, &arg))
	{
		UdfError(theEnv, fn, "Second argument must be a multifield, fact, or instance");
		return;
	}

	memset(&newattr, 0, sizeof(newattr));
	if (!ParseMqAttrFromValue(theEnv, fn, &arg, &newattr))
	{
		return;
	}

	if (UDFHasNextArgument(context))
	{
		if (!UDFNextArgument(context, LEXEME_BITS, &arg))
		{
			UdfError(theEnv, fn, "Third argument must be a symbol: fact, instance, or multifield");
			return;
		}
		rtype = arg.lexemeValue->contents;
		if (strcmp(rtype, "instance") == 0)
		{
			name = "MQ-ATTR";
		}
	}

	if (UDFHasNextArgument(context))
	{
		if (strcmp(rtype, "multifield") == 0)
		{
			UdfError(theEnv, fn, "Fourth argument may only be provided when rtype is fact or instance");
			return;
		}
		else
		if (!UDFNextArgument(context, LEXEME_BITS, &arg))
		{
			WriteString(theEnv, STDERR, fn);
			WriteString(theEnv, STDERR, ": Fourth argument must be a def");
			if (strcmp(rtype, "fact") == 0)
			{
				WriteString(theEnv, STDERR, "template");
			}
			else
			if (strcmp(rtype, "instance") == 0)
			{
				WriteString(theEnv, STDERR, "class");
			}
			WriteString(theEnv, STDERR, " name\n");
			return;
		}
		name = arg.lexemeValue->contents;
	}

	errno = 0;
	if (mq_setattr(mqdes, &newattr, &oldattr) == -1)
	{
		UdfSyscallError(theEnv, fn, "mq_setattr failed");
		return;
	}

	MQ_BuildMqAttrReturn(theEnv, fn, returnValue, &oldattr, rtype, name);
}

typedef enum
{
	CGT_RTYPE_UNKNOWN = -1,
	CGT_RTYPE_MULTIFIELD,
	CGT_RTYPE_FACT,
	CGT_RTYPE_INSTANCE
} ClockGettimeReturnType;

static bool ParseClockIdFromValue(Environment *theEnv, const char *fn, UDFValue *val, clockid_t *out)
{
	if (!out)
	{
		UdfError(theEnv, fn, "internal error: NULL clockid_t");
		return false;
	}

	if (val->header->type == INTEGER_TYPE)
	{
		*out = (clockid_t) val->integerValue->contents;
		return true;
	}

	if (val->header->type != SYMBOL_TYPE)
	{
		UdfError(theEnv, fn, "clock-id must be integer or symbol");
		return false;
	}

	const char *s = val->lexemeValue->contents;

	if (strcmp(s, "multifield") == 0 || strcmp(s, "fact") == 0 || strcmp(s, "instance") == 0)
	{
		UdfError(theEnv, fn, "clock-id cannot be rtype keyword");
		return false;
	}

#ifdef CLOCK_REALTIME
	if (strcmp(s, "CLOCK_REALTIME") == 0) { *out = CLOCK_REALTIME; return true; }
#endif
#ifdef CLOCK_MONOTONIC
	if (strcmp(s, "CLOCK_MONOTONIC") == 0) { *out = CLOCK_MONOTONIC; return true; }
#endif
#ifdef CLOCK_PROCESS_CPUTIME_ID
	if (strcmp(s, "CLOCK_PROCESS_CPUTIME_ID") == 0) { *out = CLOCK_PROCESS_CPUTIME_ID; return true; }
#endif
#ifdef CLOCK_THREAD_CPUTIME_ID
	if (strcmp(s, "CLOCK_THREAD_CPUTIME_ID") == 0) { *out = CLOCK_THREAD_CPUTIME_ID; return true; }
#endif
#ifdef CLOCK_MONOTONIC_RAW
	if (strcmp(s, "CLOCK_MONOTONIC_RAW") == 0) { *out = CLOCK_MONOTONIC_RAW; return true; }
#endif
#ifdef CLOCK_REALTIME_COARSE
	if (strcmp(s, "CLOCK_REALTIME_COARSE") == 0) { *out = CLOCK_REALTIME_COARSE; return true; }
#endif
#ifdef CLOCK_MONOTONIC_COARSE
	if (strcmp(s, "CLOCK_MONOTONIC_COARSE") == 0) { *out = CLOCK_MONOTONIC_COARSE; return true; }
#endif
#ifdef CLOCK_BOOTTIME
	if (strcmp(s, "CLOCK_BOOTTIME") == 0) { *out = CLOCK_BOOTTIME; return true; }
#endif
#ifdef CLOCK_TAI
	if (strcmp(s, "CLOCK_TAI") == 0) { *out = CLOCK_TAI; return true; }
#endif

	UdfError2(theEnv, fn, "invalid/unsupported clock-id symbol ", s);
	return false;
}

static void TimespecNormalize(struct timespec *ts)
{
	if (!ts) return;

	while (ts->tv_nsec >= 1000000000L)
	{
		ts->tv_nsec -= 1000000000L;
		ts->tv_sec += 1;
	}
	while (ts->tv_nsec < 0)
	{
		ts->tv_nsec += 1000000000L;
		ts->tv_sec -= 1;
	}
}

static void TimespecAdd(struct timespec *a, const struct timespec *b)
{
	if (!a || !b) return;
	a->tv_sec  += b->tv_sec;
	a->tv_nsec += b->tv_nsec;
	TimespecNormalize(a);
}

static bool TimespecTemplateHasSlots(Environment *theEnv, const char *fn, const char *tmpl)
{
	Deftemplate *dt = FindDeftemplate(theEnv, tmpl);
	if (!dt)
	{
		UdfError3(theEnv, fn, "could not find deftemplate '", tmpl, "'");
		return false;
	}
	if (!DeftemplateSlotExistP(dt, "sec") || !DeftemplateSlotExistP(dt, "nsec"))
	{
		UdfError3(theEnv, fn, "deftemplate '", tmpl, "' must have integer slots 'sec' and 'nsec'");
		return false;
	}
	return true;
}

static bool TimespecClassHasSlots(Environment *theEnv, const char *fn, const char *cls)
{
	Defclass *dc = FindDefclass(theEnv, cls);
	if (!dc)
	{
		UdfError3(theEnv, fn, "could not find defclass '", cls, "'");
		return false;
	}
	if (!SlotExistP(dc, "sec", true) || !SlotExistP(dc, "nsec", true))
	{
		UdfError3(theEnv, fn, "defclass '", cls, "' must have integer slots 'sec' and 'nsec'");
		return false;
	}
	return true;
}

static void CGT_BuildReturnMultifield(Environment *theEnv, UDFValue *returnValue, const struct timespec *ts)
{
	MultifieldBuilder *mb = CreateMultifieldBuilder(theEnv, 2);

	MBAppendInteger(mb, ts->tv_sec);
	MBAppendInteger(mb, ts->tv_nsec);

	returnValue->multifieldValue = MBCreate(mb);
	MBDispose(mb);
}

static void CGT_BuildReturnFact(Environment *theEnv, UDFValue *returnValue, const struct timespec *ts, const char *deftemplateName)
{
	CLIPSValue cv;
	const char *fn = "clock-gettime";

	if (!deftemplateName) deftemplateName = "timespec";

	returnValue->lexemeValue = FalseSymbol(theEnv);

	if (!TimespecTemplateHasSlots(theEnv, fn, deftemplateName))
	{
		return;
	}

	FactBuilder *fb = CreateFactBuilder(theEnv, deftemplateName);
	if (!fb)
	{
		UdfError3(theEnv, fn, "could not create FactBuilder for '", deftemplateName, "'");
		return;
	}

	cv.integerValue = CreateInteger(theEnv, ts->tv_sec);
	if (!MqFbPutSlot(theEnv, fn, fb, "sec", deftemplateName, &cv)) return;
	cv.integerValue = CreateInteger(theEnv, ts->tv_nsec);
	if (!MqFbPutSlot(theEnv, fn, fb, "nsec", deftemplateName, &cv)) return;

	Fact *f = FBAssert(fb);
	FBDispose(fb);

	if (!f)
	{
		UdfError3(theEnv, fn, "failed to assert '", deftemplateName, "' fact");
		return;
	}

	returnValue->factValue = f;
}

static void CGT_BuildReturnInstance(Environment *theEnv, UDFValue *returnValue, const struct timespec *ts, const char *defclassName, const char *instanceName)
{
	CLIPSValue cv;
	const char *fn = "clock-gettime";

	if (!defclassName) defclassName = "TIMESPEC";

	returnValue->lexemeValue = FalseSymbol(theEnv);

	if (!TimespecClassHasSlots(theEnv, fn, defclassName))
	{
		return;
	}

	InstanceBuilder *ib = CreateInstanceBuilder(theEnv, defclassName);
	if (!ib)
	{
		UdfError3(theEnv, fn, "could not create InstanceBuilder for '", defclassName, "'");
		return;
	}

	cv.integerValue = CreateInteger(theEnv, ts->tv_sec);
	if (!MqIbPutSlot(theEnv, fn, ib, "sec", defclassName, &cv)) return;
	cv.integerValue = CreateInteger(theEnv, ts->tv_nsec);
	if (!MqIbPutSlot(theEnv, fn, ib, "nsec", defclassName, &cv)) return;

	Instance *ins = IBMake(ib, instanceName);
	IBDispose(ib);

	if (!ins)
	{
		UdfError3(theEnv, fn, "failed to create '", defclassName, "' instance");
		return;
	}

	returnValue->instanceValue = ins;
}

static bool CGT_ParseRTypeSymbol(Environment *theEnv, const char *fn, const char *sym, ClockGettimeReturnType *rtypeOut)
{
	if (!rtypeOut) return false;

	if (strcmp(sym, "multifield") == 0) { *rtypeOut = CGT_RTYPE_MULTIFIELD; return true; }
	if (strcmp(sym, "fact")      == 0) { *rtypeOut = CGT_RTYPE_FACT;       return true; }
	if (strcmp(sym, "instance")  == 0) { *rtypeOut = CGT_RTYPE_INSTANCE;   return true; }

	UdfError2(theEnv, fn, "invalid rtype symbol ", sym);
	return false;
}

static void ClockGettimeFunction(Environment *theEnv, UDFContext *context, UDFValue *returnValue)
{
	const char *fn = "clock-gettime";
	unsigned int argc = UDFArgumentCount(context);

	UDFValue a1, a2, a3, a4, a5;

	clockid_t clockId =
#ifdef CLOCK_REALTIME
		CLOCK_REALTIME
#else
		((clockid_t)0)
#endif
		;

	struct timespec offset;
	struct timespec now;

	bool haveOffset  = false;

	ClockGettimeReturnType rtype = CGT_RTYPE_UNKNOWN;
	const char *deftemplateName = NULL;
	const char *defclassName = NULL;
	const char *instanceName = NULL;

	memset(&offset, 0, sizeof(offset));
	memset(&now, 0, sizeof(now));

	returnValue->value = FalseSymbol(theEnv);

	if (argc >= 1)
	{
		if (!UDFNthArgument(context, 1, ANY_TYPE_BITS, &a1)) return;

		if (a1.header->type == SYMBOL_TYPE)
		{
			const char *s = a1.lexemeValue->contents;

			if (strcmp(s, "multifield") == 0 || strcmp(s, "fact") == 0 || strcmp(s, "instance") == 0)
			{
				if (!CGT_ParseRTypeSymbol(theEnv, fn, s, &rtype)) return;
			}
			else
			{
				if (!ParseClockIdFromValue(theEnv, fn, &a1, &clockId)) return;
			}
		}
		else if (a1.header->type == INTEGER_TYPE)
		{
			if (!ParseClockIdFromValue(theEnv, fn, &a1, &clockId)) return;
		}
		else
		{
			if (!ParseTimespecFromValue(theEnv, fn, &a1, &offset)) return;
			haveOffset = true;
		}
	}

	if (argc >= 2)
	{
		if (!UDFNthArgument(context, 2, ANY_TYPE_BITS, &a2)) return;

		if (!haveOffset && (a2.header->type == MULTIFIELD_TYPE || a2.header->type == FACT_ADDRESS_TYPE ||
		                    a2.header->type == INSTANCE_ADDRESS_TYPE || a2.header->type == INTEGER_TYPE))
		{
			if (!ParseTimespecFromValue(theEnv, fn, &a2, &offset)) return;
			haveOffset = true;
		}
		else if (a2.header->type == SYMBOL_TYPE)
		{
			if (rtype == CGT_RTYPE_UNKNOWN)
			{
				if (!CGT_ParseRTypeSymbol(theEnv, fn, a2.lexemeValue->contents, &rtype)) return;
			}
			else
			{
				if (rtype == CGT_RTYPE_FACT)
				{
					deftemplateName = a2.lexemeValue->contents;
				}
				else if (rtype == CGT_RTYPE_INSTANCE)
				{
					if (FindDefclass(theEnv, a2.lexemeValue->contents) != NULL)
						defclassName = a2.lexemeValue->contents;
					else
						instanceName = a2.lexemeValue->contents;
				}
				else
				{
					UdfError(theEnv, fn, "no additional arguments allowed for multifield rtype");
					return;
				}
			}
		}
		else
		{
			UdfError(theEnv, fn, "unexpected 2nd argument");
			return;
		}
	}

	if (argc >= 3)
	{
		if (!UDFNthArgument(context, 3, ANY_TYPE_BITS, &a3)) return;

		if (a3.header->type != SYMBOL_TYPE)
		{
			UdfError(theEnv, fn, "3rd argument must be symbol (rtype or template/class name)");
			return;
		}

		if (rtype == CGT_RTYPE_UNKNOWN)
		{
			if (!CGT_ParseRTypeSymbol(theEnv, fn, a3.lexemeValue->contents, &rtype)) return;
		}
		else
		{
			if (rtype == CGT_RTYPE_FACT)
			{
				deftemplateName = a3.lexemeValue->contents;
			}
			else if (rtype == CGT_RTYPE_INSTANCE)
			{
				if (FindDefclass(theEnv, a3.lexemeValue->contents) != NULL)
					defclassName = a3.lexemeValue->contents;
				else
					instanceName = a3.lexemeValue->contents;
			}
			else
			{
				UdfError(theEnv, fn, "no additional arguments allowed for multifield rtype");
				return;
			}
		}
	}

	if (argc >= 4)
	{
		if (!UDFNthArgument(context, 4, ANY_TYPE_BITS, &a4)) return;

		if (a4.header->type != SYMBOL_TYPE)
		{
			UdfError(theEnv, fn, "4th argument must be symbol");
			return;
		}

		if (rtype == CGT_RTYPE_FACT)
		{
			if (deftemplateName != NULL)
			{
				UdfError(theEnv, fn, "deftemplate already specified");
				return;
			}
			deftemplateName = a4.lexemeValue->contents;
		}
		else if (rtype == CGT_RTYPE_INSTANCE)
		{
			if (defclassName == NULL)
			{
				if (FindDefclass(theEnv, a4.lexemeValue->contents) != NULL)
					defclassName = a4.lexemeValue->contents;
				else
					instanceName = a4.lexemeValue->contents;
			}
			else
			{
				instanceName = a4.lexemeValue->contents;
			}
		}
		else
		{
			UdfError(theEnv, fn, "too many arguments");
			return;
		}
	}

	if (argc >= 5)
	{
		if (!UDFNthArgument(context, 5, ANY_TYPE_BITS, &a5)) return;

		if (a5.header->type != SYMBOL_TYPE)
		{
			UdfError(theEnv, fn, "5th argument must be symbol");
			return;
		}

		if (rtype != CGT_RTYPE_INSTANCE)
		{
			UdfError(theEnv, fn, "5th argument only valid for instance rtype");
			return;
		}

		if (defclassName == NULL && FindDefclass(theEnv, a5.lexemeValue->contents) != NULL)
		{
			defclassName = a5.lexemeValue->contents;
		}
		else
		{
			instanceName = a5.lexemeValue->contents;
		}
	}

	if (argc > 5)
	{
		UdfError(theEnv, fn, "too many arguments");
		return;
	}

	if (rtype == CGT_RTYPE_UNKNOWN)
	{
		rtype = CGT_RTYPE_MULTIFIELD;
	}

	if (rtype == CGT_RTYPE_FACT)
	{
		if (deftemplateName == NULL)
			deftemplateName = "timespec";
		if (!TimespecTemplateHasSlots(theEnv, fn, deftemplateName))
			return;
	}
	else if (rtype == CGT_RTYPE_INSTANCE)
	{
		if (defclassName == NULL)
			defclassName = "TIMESPEC";
		if (!TimespecClassHasSlots(theEnv, fn, defclassName))
			return;
	}

	errno = 0;
	if (clock_gettime(clockId, &now) != 0)
	{
		UdfSyscallError(theEnv, fn, "clock_gettime failed");
		return;
	}

	if (haveOffset)
	{
		TimespecAdd(&now, &offset);
	}

	switch (rtype)
	{
		case CGT_RTYPE_MULTIFIELD:
			CGT_BuildReturnMultifield(theEnv, returnValue, &now);
			break;

		case CGT_RTYPE_FACT:
			CGT_BuildReturnFact(theEnv, returnValue, &now, deftemplateName);
			break;

		case CGT_RTYPE_INSTANCE:
			CGT_BuildReturnInstance(theEnv, returnValue, &now, defclassName, instanceName);
			break;

		default:
			returnValue->lexemeValue = FalseSymbol(theEnv);
			break;
	}
}

static void ErrnoFunction(Environment *theEnv, UDFContext *context, UDFValue *returnValue)
{
	(void)context;

	const char *sym = "UNKNOWN";

	switch (errno)
	{
		case 0:        sym = "FALSE"; break;
		case EACCES:   sym = "EACCES"; break;
		case EAGAIN:   sym = "EAGAIN"; break;
		case EBADF:    sym = "EBADF"; break;
		case EEXIST:   sym = "EEXIST"; break;
		case EINTR:    sym = "EINTR"; break;
		case EINVAL:   sym = "EINVAL"; break;
		case EMSGSIZE: sym = "EMSGSIZE"; break;
		case ENAMETOOLONG: sym = "ENAMETOOLONG"; break;
		case ENFILE:   sym = "ENFILE"; break;
		case ENOENT:   sym = "ENOENT"; break;
		case ENOMEM:   sym = "ENOMEM"; break;
		case ENOSPC:   sym = "ENOSPC"; break;
		case ENOTDIR:  sym = "ENOTDIR"; break;
		case ENOSYS:   sym = "ENOSYS"; break;
		case EPERM:    sym = "EPERM"; break;
		case ETIMEDOUT:sym = "ETIMEDOUT"; break;

#if defined(EWOULDBLOCK) && (!defined(EAGAIN) || (EWOULDBLOCK != EAGAIN))
		case EWOULDBLOCK: sym = "EWOULDBLOCK"; break;
#endif
	}

	returnValue->lexemeValue = CreateSymbol(theEnv, sym);
}

void UserFunctions(
  Environment *env)
  {
#if MAC_XCD
#pragma unused(env)
#endif
	AddUDF(env,"mq-open","bl",2,4,";sy;mly;mly;fim",MqOpenFunction,"MqOpenFunction",NULL);
	AddUDF(env,"mq-close","bl",1,1,";l",MqCloseFunction,"MqCloseFunction",NULL);
	AddUDF(env,"mq-getattr","bfim",1,3,";l;y;y",MqGetattrFunction,"MqGetattrFunction",NULL);
	AddUDF(env,"mq-setattr","bfim",2,4,";l;fim;y;y",MqSetattrFunction,"MqSetattrFunction",NULL);
	AddUDF(env,"mq-unlink","bl",1,1,";sy",MqUnlinkFunction,"MqUnlinkFunction",NULL);
	AddUDF(env,"mq-notify","bl",1,2,";l;fim",MqNotifyFunction,"MqNotifyFunction",NULL);
	AddUDF(env,"mq-receive","bfim",1,7,";l;sylfimn;syfimn;syfimn;sy;sy",MqReceiveFunction,"MqReceiveFunction",NULL);
	AddUDF(env,"mq-send","bl",2,4,";l;fimsy;fiml;fim",MqSendFunction,"MqSendFunction",NULL);

	AddUDF(env,"clock-gettime","bfim",0,5,";fimly;fimly;y;y;y",ClockGettimeFunction,"ClockGettimeFunction",NULL);
	AddUDF(env,"errno","y",0,0,NULL,ErrnoFunction,"ErrnoFunction",NULL);
  }
