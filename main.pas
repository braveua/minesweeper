unit Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls;

type
  TCell = record
    state:Integer;
    open:Boolean;
    flag:Boolean;
  end;
  TGameState=(NEW, STARTED, FINISH);

  { TForm1 }

  TForm1 = class(TForm)
    PaintBox1: TPaintBox;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PaintBox1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PaintBox1Paint(Sender: TObject);
    function GetCellRect(x, y:Integer): TRect;
    procedure GenerateField(curX, curY:Integer);
    procedure OpenCell(x, y: Integer);
    procedure ToggleFlag(x, y: Integer);
    procedure DrawClosed(cell: TRect);
    procedure DrawEmpty(cell: TRect);
    procedure DrawNum(cell: TRect; num: Integer);
    procedure DrawMine(cell: TRect);
    procedure DrawFlag(cell: TRect);
    procedure FieldInit;
    procedure GameOver;
  private
    XMAX: Integer;
    YMAX: Integer;
    SIZE: Integer;
    BOMBMAX: Integer;
    SAFERADIUS: Integer;
    ShowHidden: Boolean;
    State: TGameState;
  public

  end;

const
// Индексы соответствуют цифрам от 1 до 8
  MINESWEEPER_COLORS: array[1..8] of LongWord = (
    $FF0000, // 1 - Синий (Blue)
    $008000, // 2 - Зелёный (Green)
    $0000FF, // 3 - Красный (Red)
    $800000, // 4 - Тёмно-синий (Navy)
    $000080, // 5 - Бордовый (Maroon)
    $808000, // 6 - Бирюзовый (Teal)
    $000000, // 7 - Чёрный (Black)
    $808080  // 8 - Серый (Gray)
  );


  //типы клеток
  EmptyCell = -0;
  BombCell  = -1;
  //клетка по-умолчанию
  DefaultCell: TCell = (state: EmptyCell; open: false; flag: false);
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
  XMAX:=5;
  YMAX:=5;
  SIZE:=30;
  BOMBMAX:=4;
  SAFERADIUS:=2;

  form1.ClientWidth:=XMAX*SIZE;
  form1.ClientHeight:=YMAX*SIZE;

  State:=NEW;

  SetLength(field,XMAX,YMAX);

  ShowHidden := False;
  FieldInit;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);      //проверка на CTRL-H
begin
  // Проверяем, что зажат Ctrl и нажата клавиша H
  if (ssCtrl in Shift) and (Key = Ord('H')) then
  begin
    ShowHidden := not ShowHidden; // Переключаем режим (вкл/выкл)
    PaintBox1.Invalidate; // Принудительно заставляем PaintBox перерисоваться с новыми условиями
    Key := 0; // Сообщаем системе, что кнопка обработана
  end;
end;

procedure TForm1.PaintBox1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer); // MouseClick
begin
  case Button of
    mbLeft: OpenCell(X div SIZE, Y div SIZE);
    mbRight: ToggleFlag(X div SIZE, Y div SIZE);
  end;
  PaintBox1.Invalidate;
end;

procedure TForm1.PaintBox1Paint(Sender: TObject);        //отрисовка поля
var
  x, y: Integer;
  cell: TRect;
begin
  for y:=0 to YMAX-1 do
    for x := 0 to XMAX - 1 do begin
      cell:=GetCellRect(x,y);

      if not field[x, y].open then
        if field[x,y].flag then
          DrawFlag(cell)
        else
          DrawClosed(cell)
      else case field[x,y].state of
        EmptyCell: DrawEmpty(cell);
        BombCell: DrawMine(cell);
        1..8: DrawNum(cell, field[x, y].state);
        else ;
      end;
  end;
end;

function TForm1.GetCellRect(x, y: Integer): TRect;
begin
  result := Rect(x*SIZE, y*SIZE, (x+1)*SIZE-1 , (y+1)*SIZE-1);
end;

procedure TForm1.GenerateField(curX, curY: Integer);           //генерация поля
var
  x, y: Integer;
  dx, dy: Integer;
  b: Integer;
  cnt, c, r: Integer;
begin
  //
  //ГЕНЕРАЦИЯ ПОЛЯ!!!!!!!!!!!!!!!!!!
  //
  Randomize;
  cnt:=0;
  //Генерируем мины
  while cnt<BOMBMAX do begin
    x:= Random(XMAX);
    y:= Random(YMAX);
    if Field[x,y].State = EmptyCell then begin
      //if (x=curX) and (y=curY) then continue;
      if (Abs(curX-x)<SAFERADIUS) and (Abs(curY-y)<SAFERADIUS) then continue;
      Field[x,y].State:=BombCell;
      cnt:=cnt + 1;
    end;
  end;

  //Рачет мин в соседник клетках
  for y:=0 to XMAX - 1 do
    for x:=0 to YMAX - 1 do  begin
      if field[x, y].state = BombCell then continue;
      for dx:=-1 to 1 do
        for dy:=-1 to 1 do begin
          c:=x+dx;
          r:=y+dy;
          if (c < 0) or (c > XMAX - 1) then continue;
          if (r < 0) or (r > YMAX - 1) then continue;
          if field[c,r].state=BombCell then
            inc(field[x,y].state);
        end;
    end;

  ////Открываем все поле (для теста)
  //For x:= 0 to XMAX - 1 do
  //  For y:=0 to YMAX - 1 do begin
  //    field[x,y].open:=True;
  //  end;
  ////Рисуем поле
  //PaintBox1.Invalidate;
end;

procedure TForm1.OpenCell(x, y: Integer);
var
  dx, dy: integer;
begin
  if (x<0) or (x>XMAX-1) or (y<0) or (y>YMAX-1) then exit;
  if field[x,y].open then exit;
  if State = NEW then begin
    GenerateField(x,y);
    State := STARTED;
  end;
  if field[x, y].state = BombCell then
    GameOver; //game over

  if field[x,y].state = EmptyCell then begin
    for dx:= x-1 to x+1 do
      for dy:= y-1 to y+1 do begin
        writeln(dx, ' : ',dy);
        OpenCell(dx,dy);
      end;
  end;
  //field[x,y].open:=not field[x,y].open;
  field[x,y].open := True;
end;

procedure TForm1.ToggleFlag(x, y: Integer);
begin
  field[x,y].flag:= not field[x,y].flag;
  //if not field[x ,y].open then bgin
  //  field[x;
  //end;
  //field[x, y].state:=FlagCell;// - field[x, y].state;
  //field[x, y].open:= True;
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

  PaintBox1.Canvas.Font.Color:=MINESWEEPER_COLORS[Num];//clRed; //цвет цифры
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

  //field[0, 1].state := 1;         field[0,1].open := False;
  //field[1, 1].state :=BombCell;
  //field[2, 1].state := 2;         field[2,1].open := False;
end;

procedure TForm1.GameOver;
begin

end;

end.
