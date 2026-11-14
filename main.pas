unit Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, StdCtrls;

type
  TCell = record
    value:Integer;
    open:Boolean;
    flag:Boolean;
  end;
  TGameState=(gsReady, gsPlaying, gsWon, gsLost);

  { TfrmMain }

  TfrmMain = class(TForm)
    lbSmile: TLabel;
    lbMinesLeft: TLabel;
    lbTime: TLabel;
    pbField: TPaintBox;
    pnlTop: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure lbSmileClick(Sender: TObject);
    procedure pbFieldMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure pbFieldPaint(Sender: TObject);

  private
    Field: array of array of TCell;
    Cols: Integer;
    Rows: Integer;
    CellSize: Integer;
    MineCount: Integer;
    SafeZoneSize: Integer;
    State: TGameState;
    FlagCount: Integer;
    OpenedCount: Integer;

    function GetCellRect(x, y:Integer): TRect;
    procedure PlaceMines(SafeX, SafeY:Integer);
    procedure OpenCell(x, y: Integer);
    procedure OpenNeighbors(x, y: Integer);
    procedure ToggleFlag(x, y: Integer);
    procedure DrawClosed(cell: TRect);
    procedure DrawEmpty(cell: TRect; exploded: Boolean=False);
    procedure DrawNumber(cell: TRect; num: Integer);
    procedure DrawMine(cell: TRect; exploded: Boolean=False);
    procedure DrawFlag(cell: TRect);
    procedure NewGame;
    procedure EndGame(Won: Boolean);
  public

  end;

const
// Индексы соответствуют цифрам от 1 до 8
  NumberColors: array[1..8] of TColor = (
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
  EmptyCell = 0;
  MineCell  = -1;
  ExplodedCell  = -2;
  //клетка по-умолчанию
  DefaultCell: TCell = (value: EmptyCell; open: false; flag: false);
  //цвета
  CellFaceColor = $C0C0C0;
  CellLightColor = $FFFFFF;
  CellShadowColor = $808080;
  BevelWidth = 4;
  Smiles: array[TGameState] of String = ('😐', '😐', '😄', '😢');

var
  frmMain: TfrmMain;


implementation

{$R *.lfm}

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Rows := 5;
  Cols := 10;
  CellSize := 30;
  MineCount := 5;
  SafeZoneSize := 2;

  ClientWidth := Cols * CellSize;
  ClientHeight := Rows * CellSize + pnlTop.Height;
  lbSmile.Left:=(ClientWidth - lbSmile.Width) div 2;

  SetLength(Field, Cols, Rows);
  NewGame;
end;

procedure TfrmMain.lbSmileClick(Sender: TObject);
begin
  NewGame;
end;

procedure TfrmMain.pbFieldMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer); // MouseClick
var
  cellx, celly: Integer;
begin
  if State in [gsWon, gsLost] then exit;
  cellx := X div CellSize;
  celly := Y div CellSize;
  if (cellx < 0) or (cellx > Cols-1) then exit;
  if (celly < 0) or (celly > Rows-1) then exit;
  if (ssLeft in Shift) and (ssRight in Shift) and (Field[cellx, celly].open) then begin
    OpenNeighbors(cellx, celly);
  end
  else case Button of
    mbLeft: OpenCell(cellx, celly);
    mbRight: ToggleFlag(cellx, celly);
  end;

  if MineCount + OpenedCount = Cols*Rows then begin
    EndGame(True);  //game WIN
    exit;
  end;
  pbField.Invalidate;
end;

procedure TfrmMain.pbFieldPaint(Sender: TObject);        //отрисовка поля
var
  x, y: Integer;
  cell: TRect;
begin
  for y:=0 to Rows - 1 do
    for x := 0 to Cols - 1 do begin
      cell:=GetCellRect(x,y);

      if not Field[x, y].open then
        if Field[x,y].flag then
          DrawFlag(cell)
        else
          DrawClosed(cell)
      else case Field[x,y].value of
        EmptyCell: DrawEmpty(cell);
        MineCell: DrawMine(cell);
        ExplodedCell: DrawMine(cell, True);
        1..8: DrawNumber(cell, Field[x, y].value);
        else ;
      end;
  end;
end;

function TfrmMain.GetCellRect(x, y: Integer): TRect;  //Rect по XY
begin
  result := Rect(x * CellSize, y * CellSize, (x + 1) * CellSize - 1, (y + 1) * CellSize - 1);
end;

procedure TfrmMain.PlaceMines(SafeX, SafeY: Integer);   //Расстановка мин
var
  x, y: Integer;
  dx, dy: Integer;
  placed, nx, ny: Integer;
begin
  Randomize;
  placed := 0;
  //Генерируем мины
  while placed < MineCount do begin
    x:= Random(Cols);
    y:= Random(Rows);
    if Field[x,y].value = EmptyCell then begin
      if (Abs(SafeX - x) < SafeZoneSize) and (Abs(SafeY - y) < SafeZoneSize) then continue;
      Field[x,y].value:=MineCell;
      Inc(placed);
    end;
  end;

  //Расчет мин в соседних клетках
  for x:=0 to Cols - 1 do
    for y:=0 to Rows - 1 do  begin
      if Field[x, y].value = MineCell then continue;
      for dx:=-1 to 1 do
        for dy:=-1 to 1 do begin
          nx := x + dx;
          ny := y + dy;
          if (nx < 0) or (nx > Cols - 1) then continue;
          if (ny < 0) or (ny > Rows - 1) then continue;
          if Field[nx, ny].value=MineCell then
            inc(Field[x, y].value);
        end;
    end;
end;

procedure TfrmMain.OpenCell(x, y: Integer);   //открытие ячейки
var
  dx, dy: integer;
begin
  if (x<0) or (x > Cols - 1) or (y<0) or (y > Rows - 1) then exit;
  if Field[x, y].open then exit;
  if Field[x, y].flag then exit;
  if State = gsReady then begin
    PlaceMines(x,y);
    State := gsPlaying;
  end;
  if Field[x, y].value = MineCell then begin
    Field[x, y].value := ExplodedCell;
    EndGame(False); //game over
    exit;
  end;

  Field[x,y].open := True;
  Inc(OpenedCount);

  if Field[x,y].value = EmptyCell then begin
    for dx:= x-1 to x+1 do
      for dy:= y-1 to y+1 do begin
        if (x=dx) and (y=dy) then continue;
        OpenCell(dx,dy);
      end;
  end;
end;

procedure TfrmMain.OpenNeighbors(x, y: Integer);  //открытие соседних ячеек
begin

end;

procedure TfrmMain.ToggleFlag(x, y: Integer); //Установка флажка
begin
  if not Field[x, y].open then
    if Field[x,y].flag then begin
      Field[x,y].flag := False;
      Dec(FlagCount);
    end
    else begin
      Field[x,y].flag := True;
      Inc(FlagCount);
    end;
end;

procedure TfrmMain.DrawEmpty(cell: TRect; exploded: Boolean);   //пустая ячейка
begin
  if exploded then
    pbField.Canvas.Brush.Color:=clRed
  else
    pbField.Canvas.Brush.Color:=CellFaceColor;
  pbField.Canvas.FillRect(cell);
end;

procedure TfrmMain.DrawNumber(cell: TRect; num: Integer);      //ячейка с цифрой
var
  ts: TTextStyle;
begin
  DrawEmpty(cell);

  pbField.Canvas.Font.Color:=NumberColors[Num];//clRed; //цвет цифры
  pbField.Canvas.Font.Size:=18;
  pbField.Canvas.Font.Style:=[fsBold];

  ts := pbField.Canvas.TextStyle;
  ts.Alignment    := taCenter;       // По горизонтали: по центру
  ts.Layout       := tlCenter;       // По вертикали: по центру
  ts.SingleLine   := True;           // Обязательно для вертикального выравнивания
  ts.Clipping     := False;          // Выключаем обрезку (на случай, если текст чуть больше box)

  pbField.Canvas.TextStyle := ts;
  pbField.Canvas.TextRect(cell, cell.left, cell.top, IntToStr(num));
end;

procedure TfrmMain.DrawMine(cell: TRect; exploded: Boolean);   //Мина
var
  cx, cy, r: Integer;
  i: Integer;
  dx, dy: Double;
begin
  DrawEmpty(cell, exploded);

  cx := (cell.Left + cell.Right) div 2;
  cy := (cell.Top + cell.Bottom) div 2;
  r  := CellSize div 3;

  // шипы (8 линий от центра наружу)
  pbField.Canvas.Pen.Style := psSolid;
  pbField.Canvas.Pen.Color := clBlack;
  pbField.Canvas.Pen.Width := 2;
  for i := 0 to 7 do
  begin
    dx := Cos(i * Pi / 4);
    dy := Sin(i * Pi / 4);
    pbField.Canvas.MoveTo(cx + Round(r * 0.5 * dx), cy + Round(r * 0.5 * dy));
    pbField.Canvas.LineTo(cx + Round((r + 4) * dx), cy + Round((r + 4) * dy));
  end;

  // корпус мины
  pbField.Canvas.Pen.Style := psClear;
  pbField.Canvas.Brush.Color := clBlack;
  pbField.Canvas.Ellipse(cx - r, cy - r, cx + r, cy + r);

  // блик
  pbField.Canvas.Brush.Color := clWhite;
  pbField.Canvas.Ellipse(cx - r div 2 - 1, cy - r div 2 - 1,
                           cx - r div 2 + 3, cy - r div 2 + 3);
end;

procedure TfrmMain.DrawFlag(cell: TRect);     //Ячейка с флагом
var
  cx: Integer;
  poleX, topY, botY, flagW, flagH: Integer;
begin
  DrawEmpty(cell);

  cx := (cell.Left + cell.Right) div 2;

  poleX  := cx;
  topY   := cell.Top + CellSize div 4;
  botY   := cell.Bottom - CellSize div 5;
  flagW  := CellSize div 2;
  flagH  := CellSize div 3;

  // шест
  pbField.Canvas.Pen.Style := psSolid;
  pbField.Canvas.Pen.Color := clBlack;
  pbField.Canvas.Pen.Width := 2;
  pbField.Canvas.MoveTo(poleX, topY);
  pbField.Canvas.LineTo(poleX, botY);

  // полотнище флага (треугольник)
  pbField.Canvas.Pen.Style := psClear;
  pbField.Canvas.Brush.Color := clRed;
  pbField.Canvas.Polygon([
    Point(poleX, topY),
    Point(poleX + flagW, topY + flagH div 2),
    Point(poleX, topY + flagH)
  ]);

  // основание
  pbField.Canvas.Pen.Style := psSolid;
  pbField.Canvas.Pen.Color := clBlack;
  pbField.Canvas.Pen.Width := 2;
  pbField.Canvas.MoveTo(cx - CellSize div 4, botY);
  pbField.Canvas.LineTo(cx + CellSize div 4, botY);
end;

procedure TfrmMain.DrawClosed(cell: TRect);   //Закрытая ячейка
var
  p1, p2, p3, p4: TPoint;
  p5, p6, p7, p8: TPoint;
begin
  p1:=cell.TopLeft;
  p3:=cell.BottomRight;
  p2:=Point(p3.x, p1.y);
  p4:=Point(p1.x, p3.y);

  p5:=Point(p1.x + BevelWidth, p1.y + BevelWidth);
  p6:=Point(p2.x - BevelWidth, p2.y + BevelWidth);
  p7:=Point(p3.x - BevelWidth, p3.y - BevelWidth);
  p8:=Point(p4.x + BevelWidth, p4.y - BevelWidth);

  pbField.Canvas.Pen.Style := psClear; //отключение обводки полигонов
  pbField.Canvas.Brush.Color := CellFaceColor;
  pbField.Canvas.Fillrect(cell);
  pbField.Canvas.Brush.Color := CellLightColor;
  pbField.Canvas.Polygon([p4, p1, p2, p6, p5, p8]);
  pbField.Canvas.Brush.Color := CellShadowColor;
  pbField.Canvas.Polygon([p2, p3, p4, p8, p7, p6]);

end;

procedure TfrmMain.NewGame;                   //Новая игра /Инициализация поля
var
  x, y: Integer;
begin
  State :=gsReady;
  lbSmile.Caption := Smiles[State];
  FlagCount := 0;
  OpenedCount := 0;
  for y:=0 to Rows - 1 do
    for x:= 0 to Cols - 1 do
      Field[x, y] := DefaultCell;
  pbField.Invalidate;
end;

procedure TfrmMain.EndGame(Won: Boolean);
var
  x, y: Integer;
begin
  if Won then State := gsWon
  else State := gsLost;
  for x:= 0 to Cols - 1 do
    for y := 0 to Rows - 1 do
      Field[x, y].open := True;
  pbField.Invalidate;
  lbSmile.Caption := Smiles[State];
end;

end.
