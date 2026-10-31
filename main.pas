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
    //procedure PaintBox1Click(Sender: TObject);
    procedure PaintBox1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PaintBox1Paint(Sender: TObject);
    function GetCellRect(x, y:Integer): TRect;
    procedure OpenCell(x, y: Integer);
    procedure ToggleFlag(x, y: Integer);
    procedure DrawClosed(cell: TRect);
    procedure DrawEmpty(cell: TRect);
    procedure DrawNum(cell: TRect; num: Integer);
    procedure DrawMine(cell: TRect);
    procedure DrawFlag(cell: TRect);
    //procedure CellEmpty(x,y: Integer);
    //procedure CellMine(x,y: Integer);
    procedure FieldInit;
  private
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
  DefaultCell: TCell = (state: EmptyCell; open: false);
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

  form1.ClientWidth:=XMAX*SIZE;
  form1.ClientHeight:=YMAX*SIZE;

  SetLength(field,XMAX,YMAX);

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

procedure TForm1.PaintBox1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  case Button of
    mbLeft: OpenCell(X div SIZE, Y div SIZE);
    mbRight: ToggleFlag(X div SIZE, Y div SIZE);
  end;
  PaintBox1.Invalidate;
end;

procedure TForm1.PaintBox1Paint(Sender: TObject);
var
  x, y: Integer;
  cell: TRect;
begin
  for y:=0 to YMAX-1 do
    for x := 0 to XMAX - 1 do begin
      cell:=GetCellRect(x,y);

      if not field[x, y].open then
         DrawClosed(cell)
      else case field[x,y].state of
        EmptyCell: DrawEmpty(cell);
        BombCell: DrawMine(cell);
        FlagCell: DrawFlag(cell);
        1..8: DrawNum(cell, field[x, y].state);
        else ;
      end;
  end;
end;

function TForm1.GetCellRect(x, y: Integer): TRect;
begin
  result := Rect(x*SIZE, y*SIZE, (x+1)*SIZE-1 , (y+1)*SIZE-1);
end;

procedure TForm1.OpenCell(x, y: Integer);
begin
  field[x,y].open:=not field[x,y].open;
end;

procedure TForm1.ToggleFlag(x, y: Integer);
begin
  //if not field[x ,y].open then bgin
  //  field[x;
  //end;
  field[x, y].state:=FlagCell;// - field[x, y].state;
  field[x, y].open:= True;
end;

procedure TForm1.DrawEmpty(cell: TRect);
begin
  PaintBox1.Canvas.Brush.Color:=ColorGray;
  PaintBox1.Canvas.FillRect(cell);
end;

procedure TForm1.DrawNum(cell: TRect; num: Integer);
var
  ts: TTextStyle;
begin
  DrawEmpty(cell);

  PaintBox1.Canvas.Font.Color:=clRed; //цвет цифры
  PaintBox1.Canvas.Font.Size:=18;
  PaintBox1.Canvas.Font.Style:=[fsBold];

  ts := PaintBox1.Canvas.TextStyle;
  ts.Alignment    := taCenter;       // По горизонтали: по центру
  ts.Layout       := tlCenter;       // По вертикали: по центру
  ts.SingleLine   := True;           // Обязательно для вертикального выравнивания
  ts.Clipping     := False;          // Выключаем обрезку (на случай, если текст чуть больше box)

  PaintBox1.Canvas.TextStyle := ts;
  PaintBox1.Canvas.TextRect(cell, cell.left, cell.top, IntToStr(num));
end;

procedure TForm1.DrawMine(cell: TRect);
var
  cx, cy, r: Integer;
  i: Integer;
  dx, dy: Double;
begin
  DrawEmpty(cell);

  cx := (cell.Left + cell.Right) div 2;
  cy := (cell.Top + cell.Bottom) div 2;
  r  := SIZE div 3;

  // шипы (8 линий от центра наружу)
  PaintBox1.Canvas.Pen.Style := psSolid;
  PaintBox1.Canvas.Pen.Color := clBlack;
  PaintBox1.Canvas.Pen.Width := 2;
  for i := 0 to 7 do
  begin
    dx := Cos(i * Pi / 4);
    dy := Sin(i * Pi / 4);
    PaintBox1.Canvas.MoveTo(cx + Round(r * 0.5 * dx), cy + Round(r * 0.5 * dy));
    PaintBox1.Canvas.LineTo(cx + Round((r + 4) * dx), cy + Round((r + 4) * dy));
  end;

  // корпус мины
  PaintBox1.Canvas.Pen.Style := psClear;
  PaintBox1.Canvas.Brush.Color := clBlack;
  PaintBox1.Canvas.Ellipse(cx - r, cy - r, cx + r, cy + r);

  // блик
  PaintBox1.Canvas.Brush.Color := clWhite;
  PaintBox1.Canvas.Ellipse(cx - r div 2 - 1, cy - r div 2 - 1,
                           cx - r div 2 + 3, cy - r div 2 + 3);
end;

procedure TForm1.DrawFlag(cell: TRect);
var
  cx: Integer;
  poleX, topY, botY, flagW, flagH: Integer;
begin
  DrawEmpty(cell);

  cx := (cell.Left + cell.Right) div 2;

  poleX  := cx;
  topY   := cell.Top + SIZE div 4;
  botY   := cell.Bottom - SIZE div 5;
  flagW  := SIZE div 2;
  flagH  := SIZE div 3;

  // шест
  PaintBox1.Canvas.Pen.Style := psSolid;
  PaintBox1.Canvas.Pen.Color := clBlack;
  PaintBox1.Canvas.Pen.Width := 2;
  PaintBox1.Canvas.MoveTo(poleX, topY);
  PaintBox1.Canvas.LineTo(poleX, botY);

  // полотнище флага (треугольник)
  PaintBox1.Canvas.Pen.Style := psClear;
  PaintBox1.Canvas.Brush.Color := clRed;
  PaintBox1.Canvas.Polygon([
    Point(poleX, topY),
    Point(poleX + flagW, topY + flagH div 2),
    Point(poleX, topY + flagH)
  ]);

  // основание
  PaintBox1.Canvas.Pen.Style := psSolid;
  PaintBox1.Canvas.Pen.Color := clBlack;
  PaintBox1.Canvas.Pen.Width := 2;
  PaintBox1.Canvas.MoveTo(cx - SIZE div 4, botY);
  PaintBox1.Canvas.LineTo(cx + SIZE div 4, botY);
end;

procedure TForm1.DrawClosed(cell: TRect);
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

procedure TForm1.FieldInit;
var
  x, y: Integer;
begin
  for y:=0 to YMAX - 1 do
    for x:= 0 to XMAX - 1 do
      field[x, y] := DefaultCell;

  field[0, 1].state := 1;         field[0,1].open := False;
  field[1, 1].state :=BombCell;
  field[2, 1].state := 2;         field[2,1].open := False;
end;

end.
