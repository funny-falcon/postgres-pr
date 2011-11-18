#include "ruby.h"

static ID id_readbyte;
static VALUE rb_str_get_int16_network(VALUE self, VALUE position)
{
  long pos = NUM2LONG(position);
  if (pos + 2 > RSTRING_LEN(self))
    return Qnil;
  else {
    const unsigned char *buf = RSTRING_PTR(self);
    long byte1 = buf[pos],
         byte2 = buf[pos+1];
    long res = (byte1 < 128 ? byte1 : byte1 - 256) * 256 + byte2;
    return LONG2FIX(res);
  }
}

static VALUE rb_str_get_int32_network(VALUE self, VALUE position)
{
  long pos = NUM2LONG(position);
  if (pos + 4 > RSTRING_LEN(self))
    return Qnil;
  else {
    const unsigned char *buf = RSTRING_PTR(self);
    long byte1 = buf[pos],
         byte2 = buf[pos+1],
         byte3 = buf[pos+2],
         byte4 = buf[pos+3];
    long res = (((byte1 < 128 ? byte1 : byte1 - 256) * 256 + byte2) * 256 +
               byte3) * 256 + byte4;
    return LONG2NUM(res);
  }
}

static VALUE rb_read_int16_network(VALUE self)
{
  VALUE B1, B2;
  long byte1, byte2, res;
  B1 = rb_funcall(self, id_readbyte, 0);
  B2 = rb_funcall(self, id_readbyte, 0);
  byte1 = FIX2LONG(B1);
  byte2 = FIX2LONG(B2);
  res = (byte1 < 128 ? byte1 : byte1 - 256) * 256 + byte2;
  return LONG2FIX(res);
}

static VALUE rb_read_int32_network(VALUE self)
{
  VALUE B1, B2, B3, B4;
  long byte1, byte2, byte3, byte4, res;
  B1 = rb_funcall(self, id_readbyte, 0);
  B2 = rb_funcall(self, id_readbyte, 0);
  B3 = rb_funcall(self, id_readbyte, 0);
  B4 = rb_funcall(self, id_readbyte, 0);
  byte1 = FIX2LONG(B1);
  byte2 = FIX2LONG(B2);
  byte3 = FIX2LONG(B3);
  byte4 = FIX2LONG(B4);
  res = (((byte1 < 128 ? byte1 : byte1 - 256) * 256 + byte2) * 256 +
	   byte3) * 256 + byte4;
  return LONG2NUM(res);
}


void Init_unpack_single() {
  VALUE mod_unpack;
  rb_define_method(rb_cString, "get_int16_network", rb_str_get_int16_network, 1);
  rb_define_method(rb_cString, "get_int32_network", rb_str_get_int32_network, 1);
  id_readbyte = rb_intern("readbyte");
  mod_unpack = rb_define_module("ReadUnpack");
  rb_define_method(mod_unpack, "read_int16_network", rb_read_int16_network, 0);
  rb_define_method(mod_unpack, "read_int32_network", rb_read_int32_network, 0);
}
