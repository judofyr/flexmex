#include "ruby.h"
#include "ruby/encoding.h"
#include "Yoga.h"

static VALUE cNode;
static VALUE mAlign;
static VALUE mDirection;
static VALUE mDisplay;
static VALUE mEdge;
static VALUE mFlexDirection;
static VALUE mFlexmex;
static VALUE mOverflow;
static VALUE mUnit;
static VALUE mWrap;

static void node_dealloc(YGNodeRef ynode)
{
  YGNodeFree(ynode);
}

static void node_mark(YGNodeRef ynode)
{
  // TODO: Follow children
}

static VALUE node_alloc(VALUE klass)
{
  static YGConfigRef config = NULL;
  if (config == NULL) {
    config = YGConfigNew();
    YGConfigSetPointScaleFactor(config, 0.0f);
  }

  YGNodeRef ynode = YGNodeNewWithConfig(config);
  VALUE self = Data_Wrap_Struct(klass, node_mark, node_dealloc, ynode);
  YGNodeSetContext(ynode, (void*)self);
  return self;
}

static VALUE node_calculate_layout(VALUE self, VALUE width, VALUE height)
{
  YGNodeRef selfnode;
  Data_Get_Struct(self, void, selfnode);

  YGNodeCalculateLayout(selfnode, NUM2DBL(width), NUM2DBL(height), YGDirectionLTR);

  return self;
}

static VALUE node_layout(VALUE self)
{
  YGNodeRef selfnode;
  Data_Get_Struct(self, void, selfnode);

  float left = YGNodeLayoutGetLeft(selfnode);
  float top = YGNodeLayoutGetTop(selfnode);
  //float right = YGNodeLayoutGetRight(selfnode);
  //float bottom = YGNodeLayoutGetBottom(selfnode);
  float width = YGNodeLayoutGetWidth(selfnode);
  float height = YGNodeLayoutGetHeight(selfnode);

  return rb_ary_new_from_args(4,
      rb_float_new(left), rb_float_new(top),
      rb_float_new(width), rb_float_new(height)
  );
}

static YGSize measure(YGNodeRef node,
    float width, YGMeasureMode widthMode,
    float height, YGMeasureMode heightMode)
{
  VALUE self = (VALUE) YGNodeGetContext(node);

  VALUE reqWidth = Qnil;
  VALUE reqHeight = Qnil;

  if (widthMode != YGMeasureModeUndefined) {
    reqWidth = rb_float_new(width);
  }

  if (heightMode != YGMeasureModeUndefined) {
    reqHeight = rb_float_new(height);
  }

  VALUE result = rb_funcall(self, rb_intern("measure"), 2, reqWidth, reqHeight);

  Check_Type(result, T_ARRAY);

  YGSize size;
  size.width = NUM2DBL(rb_ary_entry(result, 0));
  size.height = NUM2DBL(rb_ary_entry(result, 1));

  if (widthMode == YGMeasureModeAtMost && size.width > width) {
    size.width = width;
  }

  if (heightMode == YGMeasureModeAtMost && size.height > height) {
    size.height = height;
  }

  return size;
}

static VALUE node_enable_measure(VALUE self)
{
  YGNodeRef selfnode;
  Data_Get_Struct(self, void, selfnode);

  YGNodeSetMeasureFunc(selfnode, measure);

  return self;
}

static VALUE node_mark_dirty(VALUE self)
{
  YGNodeRef selfnode;
  Data_Get_Struct(self, void, selfnode);

  YGNodeMarkDirty(selfnode);

  return self;
}

static VALUE node_print_debug(VALUE self)
{
  YGNodeRef selfnode;
  Data_Get_Struct(self, void, selfnode);

  YGNodePrint(selfnode, (1 << YGPrintOptionsCount)-1);

  return self;
}

static VALUE node_child_count(VALUE self)
{
  YGNodeRef selfnode;

  Data_Get_Struct(self, void, selfnode);

  return INT2FIX(YGNodeGetChildCount(selfnode));
}

static VALUE node_insert_child(VALUE self, VALUE child, VALUE idxval)
{
  YGNodeRef selfnode, childnode;

  Data_Get_Struct(self, void, selfnode);
  Data_Get_Struct(child, void, childnode);

  unsigned int idx = NUM2UINT(idxval);

  YGNodeInsertChild(selfnode, childnode, idx);

  return self;
}

static VALUE node_remove_child(VALUE self, VALUE child)
{
  YGNodeRef selfnode, childnode;

  Data_Get_Struct(self, void, selfnode);
  Data_Get_Struct(child, void, childnode);

  YGNodeRemoveChild(selfnode, childnode);

  return self;
}

static VALUE node_each_child(VALUE self)
{
  YGNodeRef selfnode;

  Data_Get_Struct(self, void, selfnode);

  uint32_t count = YGNodeGetChildCount(selfnode);
  for (uint32_t idx = 0; idx < count; idx++) {
    YGNodeRef childnode = YGNodeGetChild(selfnode, idx);
    VALUE child = (VALUE) YGNodeGetContext(childnode);
    rb_yield(child);
  }

  return self;
}


#define DEF_STYLE_PROPERTY(name, to_rb, from_rb) \
static VALUE node_style_get_##name(VALUE self) \
{ \
  YGNodeRef selfnode; \
  Data_Get_Struct(self, void, selfnode); \
  return to_rb(YGNodeStyleGet##name(selfnode)); \
} \
static VALUE node_style_set_##name(VALUE self, VALUE val) \
{ \
  YGNodeRef selfnode; \
  Data_Get_Struct(self, void, selfnode); \
  YGNodeStyleSet##name(selfnode, from_rb(val)); \
  return self; \
}

#define DEF_UNIT_PROPERTY(name) \
static VALUE node_style_set_##name(VALUE self, VALUE val) \
{ \
  YGNodeRef selfnode; \
  Check_Type(val, T_FLOAT); \
  Data_Get_Struct(self, void, selfnode); \
  YGNodeStyleSet##name(selfnode, NUM2DBL(val)); \
  return self; \
}

#define DEF_EDGE_PROPERTY(name) \
static VALUE node_style_get_##name(VALUE self, VALUE edge) \
{ \
  YGNodeRef selfnode; \
  Data_Get_Struct(self, void, selfnode); \
  YGValue value = YGNodeStyleGet##name(selfnode, FIX2INT(edge)); \
  return rb_float_new(value.value); \
} \
static VALUE node_style_set_##name(VALUE self, VALUE edge, VALUE val) \
{ \
  YGNodeRef selfnode; \
  Check_Type(edge, T_FIXNUM); \
  Check_Type(val, T_FLOAT); \
  Data_Get_Struct(self, void, selfnode); \
  YGNodeStyleSet##name(selfnode, FIX2INT(edge), NUM2DBL(val)); \
  return self; \
} \
static VALUE node_style_set_percent_##name(VALUE self, VALUE edge, VALUE val) \
{ \
  YGNodeRef selfnode; \
  Check_Type(edge, T_FIXNUM); \
  Check_Type(val, T_FLOAT); \
  Data_Get_Struct(self, void, selfnode); \
  YGNodeStyleSet##name##Percent(selfnode, FIX2INT(edge), NUM2DBL(val)); \
  return self; \
}

#define DEF_EDGE_LAYOUT_PROPERTY(name) \
static VALUE node_style_get_layout_##name(VALUE self, VALUE edge) \
{ \
  YGNodeRef selfnode; \
  Data_Get_Struct(self, void, selfnode); \
  float value = YGNodeLayoutGet##name(selfnode, FIX2INT(edge)); \
  return rb_float_new(value); \
}

#define DEF_FLOAT_PROPERTY(name) \
  DEF_STYLE_PROPERTY(name, rb_float_new, NUM2DBL)

#define DEF_ENUM_PROPERTY(name) \
  DEF_STYLE_PROPERTY(name, INT2FIX, FIX2INT)

DEF_FLOAT_PROPERTY(Flex)
DEF_FLOAT_PROPERTY(FlexGrow)
DEF_FLOAT_PROPERTY(FlexShrink)
DEF_ENUM_PROPERTY(Direction)
DEF_ENUM_PROPERTY(FlexDirection)
DEF_ENUM_PROPERTY(AlignContent)
DEF_ENUM_PROPERTY(AlignItems)
DEF_ENUM_PROPERTY(AlignSelf)
DEF_ENUM_PROPERTY(PositionType)
DEF_ENUM_PROPERTY(FlexWrap)
DEF_ENUM_PROPERTY(Overflow)
DEF_ENUM_PROPERTY(Display)

DEF_UNIT_PROPERTY(MaxHeight)
DEF_UNIT_PROPERTY(MaxWidth)

DEF_EDGE_PROPERTY(Margin)
DEF_EDGE_PROPERTY(Padding)
DEF_EDGE_PROPERTY(Position)

DEF_EDGE_LAYOUT_PROPERTY(Border)

static VALUE node_style_get_Border(VALUE self, VALUE edge)
{
  YGNodeRef selfnode;
  Data_Get_Struct(self, void, selfnode);
  float value = YGNodeStyleGetBorder(selfnode, FIX2INT(edge));
  return value;
}

static VALUE node_style_set_Border(VALUE self, VALUE edge, VALUE val)
{
  YGNodeRef selfnode;
  Check_Type(edge, T_FIXNUM);
  Check_Type(val, T_FLOAT);
  Data_Get_Struct(self, void, selfnode);
  YGNodeStyleSetBorder(selfnode, FIX2INT(edge), NUM2DBL(val));
  return self;
}

static VALUE node_style_set_JustifyContent(VALUE self, VALUE val)
{
  YGNodeRef selfnode;
  Check_Type(val, T_FIXNUM);
  Data_Get_Struct(self, void, selfnode);
  static int mapping[] = {
    /* YGAlignAuto = */ -1,
    /* YGAlignFlexStart = */ YGJustifyFlexStart,
    /* YGAlignCenter = */ YGJustifyCenter,
    /* YGAlignFlexEnd = */ YGJustifyFlexEnd,
    /* YGAlignStretch = */ -1,
    /* YGAlignBaseline = */ -1,
    /* YGAlignSpaceBetween = */ YGJustifySpaceBetween,
    /* YGAlignSpaceAround = */ YGJustifySpaceAround
  };

  int intval = FIX2INT(val);
  if (intval >= 0 && intval < YGAlignCount) {
    intval = mapping[intval];
  }

  YGNodeStyleSetJustifyContent(selfnode, intval);
  return self;
}

void Init_flexmex_ext()
{
  mFlexmex = rb_define_module("Flexmex");

  mAlign = rb_define_module_under(mFlexmex, "Align");
  rb_define_const(mAlign, "Auto", INT2FIX(YGAlignAuto));
  rb_define_const(mAlign, "FlexStart", INT2FIX(YGAlignFlexStart));
  rb_define_const(mAlign, "Center", INT2FIX(YGAlignCenter));
  rb_define_const(mAlign, "FlexEnd", INT2FIX(YGAlignFlexEnd));
  rb_define_const(mAlign, "Stretch", INT2FIX(YGAlignStretch));
  rb_define_const(mAlign, "Baseline", INT2FIX(YGAlignBaseline));
  rb_define_const(mAlign, "SpaceBetween", INT2FIX(YGAlignSpaceBetween));
  rb_define_const(mAlign, "SpaceAround", INT2FIX(YGAlignSpaceAround));

  mDirection = rb_define_module_under(mFlexmex, "Direction");
  rb_define_const(mDirection, "LTR", INT2FIX(YGDirectionLTR));
  rb_define_const(mDirection, "RTL", INT2FIX(YGDirectionRTL));

  mDisplay = rb_define_module_under(mFlexmex, "Display");
  rb_define_const(mDisplay, "Flex", INT2FIX(YGDisplayFlex));
  rb_define_const(mDisplay, "None", INT2FIX(YGDisplayNone));

  mEdge = rb_define_module_under(mFlexmex, "Edge");
  rb_define_const(mEdge, "Left", INT2FIX(YGEdgeLeft));
  rb_define_const(mEdge, "Top", INT2FIX(YGEdgeTop));
  rb_define_const(mEdge, "Right", INT2FIX(YGEdgeRight));
  rb_define_const(mEdge, "Bottom", INT2FIX(YGEdgeBottom));
  rb_define_const(mEdge, "Start", INT2FIX(YGEdgeStart));
  rb_define_const(mEdge, "End", INT2FIX(YGEdgeEnd));
  rb_define_const(mEdge, "Horizontal", INT2FIX(YGEdgeHorizontal));
  rb_define_const(mEdge, "Vertical", INT2FIX(YGEdgeVertical));
  rb_define_const(mEdge, "All", INT2FIX(YGEdgeAll));

  mFlexDirection = rb_define_module_under(mFlexmex, "FlexDirection");
  rb_define_const(mFlexDirection, "Column", INT2FIX(YGFlexDirectionColumn));
  rb_define_const(mFlexDirection, "ColumnReverse", INT2FIX(YGFlexDirectionColumnReverse));
  rb_define_const(mFlexDirection, "Row", INT2FIX(YGFlexDirectionRow));
  rb_define_const(mFlexDirection, "RowReverse", INT2FIX(YGFlexDirectionRowReverse));

  mOverflow = rb_define_module_under(mFlexmex, "Overflow");
  rb_define_const(mOverflow, "Visible", INT2FIX(YGOverflowVisible));
  rb_define_const(mOverflow, "Hidden", INT2FIX(YGOverflowHidden));
  rb_define_const(mOverflow, "Scroll", INT2FIX(YGOverflowScroll));

  mUnit = rb_define_module_under(mFlexmex, "Unit");
  rb_define_const(mUnit, "Undefined", INT2FIX(YGUnitUndefined));
  rb_define_const(mUnit, "Point", INT2FIX(YGUnitPoint));
  rb_define_const(mUnit, "Percent", INT2FIX(YGUnitPercent));
  rb_define_const(mUnit, "Auto", INT2FIX(YGUnitAuto));

  mWrap = rb_define_module_under(mFlexmex, "FlexWrap");
  rb_define_const(mWrap, "Wrap", INT2FIX(YGWrapWrap));

  cNode = rb_define_class_under(mFlexmex, "Node", rb_cObject);
  rb_define_alloc_func(cNode, node_alloc);

  rb_define_method(cNode, "calculate_layout", node_calculate_layout, 2);
  rb_define_method(cNode, "layout", node_layout, 0);

  rb_define_method(cNode, "print_debug", node_print_debug, 0);
  rb_define_method(cNode, "insert_child", node_insert_child, 2);
  rb_define_method(cNode, "each_child", node_each_child, 0);
  rb_define_method(cNode, "child_count", node_child_count, 0);
  rb_define_method(cNode, "remove_child", node_remove_child, 1);

  rb_define_method(cNode, "enable_measure", node_enable_measure, 0);
  rb_define_method(cNode, "mark_dirty", node_mark_dirty, 0);

  rb_define_method(cNode, "get_direction", node_style_get_Direction, 0);
  rb_define_method(cNode, "set_direction", node_style_set_Direction, 1);
  rb_define_method(cNode, "get_flex_direction", node_style_get_FlexDirection, 0);
  rb_define_method(cNode, "set_flex_direction", node_style_set_FlexDirection, 1);
  rb_define_method(cNode, "get_flex", node_style_get_Flex, 0);
  rb_define_method(cNode, "set_flex", node_style_set_Flex, 1);
  rb_define_method(cNode, "get_flex_grow", node_style_get_FlexGrow, 0);
  rb_define_method(cNode, "set_flex_grow", node_style_set_FlexGrow, 1);
  rb_define_method(cNode, "get_flex_shrink", node_style_get_FlexShrink, 0);
  rb_define_method(cNode, "set_flex_shrink", node_style_set_FlexShrink, 1);
  rb_define_method(cNode, "get_align_items", node_style_get_AlignItems, 0);
  rb_define_method(cNode, "set_align_items", node_style_set_AlignItems, 1);
  rb_define_method(cNode, "get_align_content", node_style_get_AlignContent, 0);
  rb_define_method(cNode, "set_align_content", node_style_set_AlignContent, 1);
  rb_define_method(cNode, "get_align_self", node_style_get_AlignSelf, 0);
  rb_define_method(cNode, "set_align_self", node_style_set_AlignSelf, 1);
  rb_define_method(cNode, "set_justify_content", node_style_set_JustifyContent, 1);
  rb_define_method(cNode, "get_flex_wrap", node_style_get_FlexWrap, 0);
  rb_define_method(cNode, "set_flex_wrap", node_style_set_FlexWrap, 1);

  rb_define_method(cNode, "set_max_height", node_style_set_MaxHeight, 1);
  rb_define_method(cNode, "set_max_width", node_style_set_MaxWidth, 1);

  rb_define_method(cNode, "get_overflow", node_style_get_Overflow, 0);
  rb_define_method(cNode, "set_overflow", node_style_set_Overflow, 1);
  rb_define_method(cNode, "get_display", node_style_get_Display, 0);
  rb_define_method(cNode, "set_display", node_style_set_Display, 1);
  rb_define_method(cNode, "get_position_type", node_style_get_PositionType, 0);
  rb_define_method(cNode, "set_position_type", node_style_set_PositionType, 1);

  rb_define_method(cNode, "get_margin", node_style_get_Margin, 1);
  rb_define_method(cNode, "set_margin", node_style_set_Margin, 2);
  rb_define_method(cNode, "set_margin_percent", node_style_set_percent_Margin, 2);

  rb_define_method(cNode, "get_padding", node_style_get_Padding, 1);
  rb_define_method(cNode, "set_padding", node_style_set_Padding, 2);
  rb_define_method(cNode, "set_padding_percent", node_style_set_percent_Padding, 2);

  rb_define_method(cNode, "get_position", node_style_get_Position, 1);
  rb_define_method(cNode, "set_position", node_style_set_Position, 2);
  rb_define_method(cNode, "set_position_percent", node_style_set_percent_Position, 2);

  rb_define_method(cNode, "get_border", node_style_get_Border, 1);
  rb_define_method(cNode, "get_border_layout", node_style_get_layout_Border, 1);
  rb_define_method(cNode, "set_border", node_style_set_Border, 2);
}

