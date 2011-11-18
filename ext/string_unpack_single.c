#include "ruby.h"

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

void Init_unpack_single() {
  rb_define_method(rb_cString, "get_int16_network", rb_str_get_int16_network, 1);
  rb_define_method(rb_cString, "get_int32_network", rb_str_get_int32_network, 1);
}
