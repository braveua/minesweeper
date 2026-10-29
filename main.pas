unit Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls;

type
  TCell = record
    state:Integer;
    open:Boolean;
  end;

  { TForm1 }

  TForm1 = class(TForm)
    PaintBox1: TPaintBox;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PaintBox1Paint(Sender: TObject);
    procedure DrawNew(cell: TRect);
    procedure DrawEmpty(cell: TRect);
    procedure CellEmpty(x,y: Integer);
    procedure CellMine(x,y: Integer);
    procedure FieldInit;
  private
    //ColorGray:TColor;
    //ColorWhite:TColor;
    //ColorDark:TColor;
    XMAX: Integer;
    YMAX: Integer;
    SIZE: Integer;
    ShowHidden: Boolean;
  public

  end;

const
  //типы клеток
  NewCell   = -4;
  EmptyCell = -3;
  FlagCell  = -2;
  BombCell  = -1;
  //клетка по-умолчанию
  DefaultCell: TCell = (state: NewCell; open: false);
  //цвета
  ColorGray = $C0C0C0;
  ColorWhite = $FFFFFF;
  ColorDark = $808080;
  //paddirg
  Padding = 4;

var
  Form1: TForm1;
  field: array of array of TCell;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  XMAX:=3;
  YMAX:=3;
  SIZE:=30;
  //ColorGray := RGBToColor(192, 192, 192);
  //ColorWhite:= RGBToColor(255, 255, 255);
  //ColorDark := RGBToColor(128, 128, 128);

  //form1.Width:=XMAX*SIZE;
  form1.ClientWidth:=XMAX*SIZE;
  //form1.Height:=YMAX*SIZE;
  form1.ClientHeight:=YMAX*SIZE;

  SetLength(field,XMAX,YMAX);
  //field[0,1].state:=1;

  ShowHidden := False;
  FieldInit;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  // Проверяем, что зажат Ctrl и нажата клавиша H
  if (ssCtrl in Shift) and (Key = Ord('H')) then
  begin
    ShowHidden := not ShowHidden; // Переключаем режим (вкл/выкл)

    PaintBox1.Invalidate; // Принудительно заставляем PaintBox перерисоваться с новыми условиями

    Key := 0; // Сообщаем системе, что кнопка обработана
  end;
end;

procedure TForm1.PaintBox1Paint(Sender: TObject);
var
  x, y: Integer;
  x0, y0, x1, y1:Integer;
  cell: TRect;
begin

  for y:=0 to YMAX-1 do
    for x := 0 to XMAX - 1 do begin
      x0 :=  x * SIZE;
      x1 := x0 + SIZE - 1;
      y0 := y * SIZE;
      y1 := y0 + SIZE - 1;
      cell := Rect(x0, y0, x1, y1);

      case field[x,y].state of
        NewCell: DrawNew(cell);
        else ;
      end;
      //if field[x,y].state=-1 then begin
      //  CellEmpty(x,y);
      //end
      //else if field[x,y].state=0 then begin
      //  DrawNew(cell);
      //end
      //else if field[x,y].state=9 then begin
      //  //CellEmpty(x,y);
      //end
      //else if field[x,y].state > 0 then begin
      //  CellMine(x,y);
      //end
      //else if field[x,y].state > 0 then begin
      //  //CellMine(x,y);
      //end;
  end;

end;

procedure TForm1.DrawEmpty(cell: TRect);
begin
  PaintBox1.Canvas.Brush.Color:=ColorGray;
  PaintBox1.Canvas.FillRect(cell);
end;

procedure TForm1.DrawNew(cell: TRect);
var
  p1, p2, p3, p4: TPoint;
  p5, p6, p7, p8: TPoint;
begin
  p1:=cell.TopLeft;
  p3:=cell.BottomRight;
  p2:=Point(p3.x, p1.y);
  p4:=Point(p1.x, p3.y);

  p5:=Point(p1.x + Padding, p1.y + Padding);
  p6:=Point(p2.x - Padding, p2.y + Padding);
  p7:=Point(p3.x - Padding, p3.y - Padding);
  p8:=Point(p4.x + Padding, p4.y - Padding);

  PaintBox1.Canvas.Pen.Style := psClear; //отключение обводки полигонов
  PaintBox1.Canvas.Brush.Color:=ColorGray;
  PaintBox1.Canvas.Fillrect(cell);
  PaintBox1.Canvas.Brush.Color:=ColorWhite;
  PaintBox1.Canvas.Polygon([p4, p1, p2, p6, p5, p8]);
  PaintBox1.Canvas.Brush.Color:=ColorDark;
  PaintBox1.Canvas.Polygon([p2, p3, p4, p8, p7, p6]);

end;

procedure TForm1.CellEmpty(x, y: Integer);
var
  p1,p2,p3,p4,p5,p6,p7,p8: TPoint;
  x0, x1, y0, y1: Integer;
  b: Integer;
begin
  b:=4;
  x0 :=  x * SIZE;
  x1 := x0 + SIZE ;
  y0 := y * SIZE;
  y1 := y0 + SIZE  ;

  p1:=Point(x0, y0);
  p2:=Point(x0, y1);
  p3:=Point(x1, y1);
  p4:=Point(x1, y0);

  p5:=Point(p1.x+b, p1.y+b);
  p6:=Point(p2.x+b, p2.y-b);
  p7:=Point(p3.x-b, p3.y-b);
  p8:=Point(p4.x-b, p4.y+b);

  PaintBox1.Canvas.Brush.Color:=ColorGray;
  PaintBox1.Canvas.FillRect(x0, y0, x1,y1);

  PaintBox1.Canvas.Pen.Style := psClear; //отключение обводки полигонов
  PaintBox1.Canvas.Brush.Color:=ColorWhite;
  PaintBox1.Canvas.Polygon([p4,p1,p2,p6,p5,p8]);
  PaintBox1.Canvas.Brush.Color:=ColorDark;
  PaintBox1.Canvas.Polygon([p2,p3,p4,p8,p7,p6]);
end;

procedure TForm1.CellMine(x, y: Integer);
var
  x0, x1, y0, y1:Integer;
  box: Trect;
  ts: TTextStyle;
begin
  x0 := x * SIZE;
  x1 := x0 + SIZE - 1;
  y0 := y * SIZE;
  y1 := y0 + SIZE - 1;

  PaintBox1.Canvas.Brush.Color:=ColorGray;
  PaintBox1.Canvas.FillRect(x0, y0, x1, y1);

  box := Rect(x0, y0, x1, y1);
  PaintBox1.Canvas.Font.Color:=clRed;
  PaintBox1.Canvas.Font.Size:=18;
  PaintBox1.Canvas.Font.Style:=[fsBold];

  ts := PaintBox1.Canvas.TextStyle;
  ts.Alignment    := taCenter;       // По горизонтали: по центру
  ts.Layout       := tlCenter;       // По вертикали: по центру
  ts.SingleLine   := True;           // Обязательно для вертикального выравнивания
  ts.Clipping     := False;          // Выключаем обрезку (на случай, если текст чуть больше box)

  PaintBox1.Canvas.TextStyle := ts;
  PaintBox1.Canvas.TextRect(box, box.left, box.top, IntToStr(Field[x,y].state));
end;

procedure TForm1.FieldInit;
var
  x, y: Integer;
begin
  for y:=0 to YMAX - 1 do
    for x:= 0 to XMAX - 1 do
      field[x, y] := DefaultCell;
  //field[0, 0].state := NewCell; //NewCell
  //field[0, 1].state := NewCell;
  //field[0, 2].state := NewCell;
  //field[1, 0].state := NewCell;
  //field[1, 1].state := NewCell;
  //field[1, 2].state := NewCell;
  //field[2, 0].state := NewCell;
  //field[2, 1].state := NewCell;
  //field[2, 2].state := NewCell;
end;



end.

