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
    imgDigits: TImage;
    lbSmile: TLabel;
    pbRest: TPaintBox;
    pbField: TPaintBox;
    pbTimer: TPaintBox;
    pnlTop: TPanel;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure lbSmileClick(Sender: TObject);
    procedure pbFieldMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure pbFieldPaint(Sender: TObject);
    procedure pbRestPaint(Sender: TObject);
    procedure pbTimerPaint(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);

  private
    Field: array of array of TCell;
    Cols: Integer;
    Rows: Integer;
    CellSize: Integer;
    MineCount: Integer;
    MineRest: Integer;
    Timer: Integer;
    State: TGameState;
    OpenedCount: Integer;

    function GetCellRect(x, y:Integer): TRect;
    procedure PlaceMines(SafeX, SafeY:Integer);
    procedure OpenCell(x, y: Integer);
    procedure OpenNeighbors(x, y: Integer);
    procedure ToggleFlag(x, y: Integer);
    procedure DrawDigits(ACanvas: TCanvas; Value: Integer);
    procedure DrawClosed(cell: TRect);
    procedure DrawEmpty(cell: TRect; exploded: Boolean=False);
    procedure DrawNumber(cell: TRect; num: Integer);
    procedure DrawMine(cell: TRect; exploded: Boolean=False);
    procedure DrawFlag(cell: TRect);
    procedure DrawWrongFlag(cell: TRect);
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
  FirstClickRadius = 1;
  DigitWidth  = 14;
  DigitHeight = 23;

  //типы клеток
  EmptyCell = 0;
  MineCell  = -1;
  ExplodedCell  = -2;
  WrongFlagCell = -3;
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
  uses
    Math;
{$R *.lfm}

function FormatCounter(Value: Integer): string; forward;

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Randomize;
  Rows := 9;
  Cols := 9;
  CellSize := 30;
  MineCount := 10;

  ClientWidth := Cols * CellSize;
  ClientHeight := Rows * CellSize + pnlTop.Height;
  lbSmile.Left:=(ClientWidth - lbSmile.Width) div 2;

  SetLength(Field, Cols, Rows);
  // FormCreate: проверка конфигурации, до начала игры
  if MineCount > Cols * Rows - Sqr(2 * FirstClickRadius + 1) then
    raise Exception.CreateFmt('Некорректный уровень: %d мин на поле %dx%d',
      [MineCount, Cols, Rows]);
  NewGame;
end;

procedure TfrmMain.lbSmileClick(Sender: TObject);
begin
  NewGame;
end;

procedure TfrmMain.pbFieldMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer); // MouseClick
var
  cellX, cellY: Integer;
begin
  if State in [gsWon, gsLost] then exit;
  cellX := X div CellSize;
  cellY := Y div CellSize;
  if (cellX < 0) or (cellX > Cols-1) then exit;
  if (cellY < 0) or (cellY > Rows-1) then exit;
  if (ssLeft in Shift) and (Field[cellX, cellY].open) and (Field[cellX, cellY].value >0) then begin
    OpenNeighbors(cellX, cellY);
  end
  else case Button of
    mbLeft: OpenCell(cellX, cellY);
    mbRight: ToggleFlag(cellX, cellY);
  end;

  if (State = gsPlaying) and (MineCount + OpenedCount = Cols*Rows) then begin
    EndGame(True);  //game WIN
    Exit;
  end;
  pbField.Invalidate;
end;

procedure TfrmMain.pbFieldPaint(Sender: TObject);        //отрисовка поля
var
  x, y: Integer;
  cell: TRect;
begin
  pbField.Canvas.Brush.Style := bsSolid;
  pbField.Canvas.Brush.Color := CellFaceColor;
  pbField.Canvas.FillRect(pbField.ClientRect);
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
        WrongFlagCell: DrawWrongFlag(cell);
        ExplodedCell: DrawMine(cell, True);
        1..8: DrawNumber(cell, Field[x, y].value);
        else ;
      end;
  end;
end;

procedure TfrmMain.DrawDigits(ACanvas: TCanvas; Value: Integer);
var
  s: string;
  i, idx: Integer;
  toRect, fromRect: TRect;
begin
  s := FormatCounter(Value);
  for i := 0 to 2 do
  begin
    idx := Pos(s[i + 1], '1234567890- ') - 1;
    if idx < 0 then idx := 11;

    toRect   := Rect(i * DigitWidth, 0, (i + 1) * DigitWidth, DigitHeight);
    fromRect := Rect(idx * DigitWidth, 0, (idx + 1) * DigitWidth, DigitHeight);

    ACanvas.CopyRect(toRect, imgDigits.Picture.Bitmap.Canvas, fromRect);
  end;
end;

procedure TfrmMain.pbRestPaint(Sender: TObject);
begin
  DrawDigits(pbRest.Canvas, MineRest);
end;

procedure TfrmMain.pbTimerPaint(Sender: TObject);
begin
  DrawDigits(pbTimer.Canvas, timer);
end;

procedure TfrmMain.Timer1Timer(Sender: TObject);
begin
  if State in [gsLost, gsWon, gsReady] then exit;
  Inc(timer);
  pbTimer.Invalidate;
end;

function TfrmMain.GetCellRect(x, y: Integer): TRect;  //Rect по XY
begin
  Result := Rect(x * CellSize, y * CellSize, (x + 1) * CellSize, (y + 1) * CellSize);
end;

procedure TfrmMain.PlaceMines(SafeX, SafeY: Integer);   //Расстановка мин
var
  x, y: Integer;
  dx, dy: Integer;
  placed, nx, ny: Integer;
begin
  placed := 0;
  //Генерируем мины
  while placed < MineCount do begin
    x:= Random(Cols);
    y:= Random(Rows);
    if Field[x,y].value = EmptyCell then begin
      if (Abs(SafeX - x) <= FirstClickRadius) and (Abs(SafeY - y) <= FirstClickRadius) then continue;
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
  if State in [gsWon, gsLost] then Exit;
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
var
  nx, ny: Integer;
  cnt: Integer;
begin
  cnt := 0;
  for nx := x - 1 to x + 1 do
    for ny := y - 1 to y + 1 do begin
      if (nx = x) and (ny = y) then continue;
      if (nx < 0) or (ny < 0) or (nx > Cols-1) or (ny > Rows - 1) then continue;
      if Field[nx, ny].flag then Inc(cnt);
    end;
  if cnt = Field[x, y].value then
    for nx := x - 1 to x + 1 do
      for ny := y - 1 to y + 1 do begin
        if (nx = x) and (ny = y) then continue;
        if (nx < 0) or (ny < 0) or (nx > Cols-1) or (ny > Rows - 1) then continue;
        if (not Field[nx, ny].flag) and (not Field[nx, ny].open) then OpenCell(nx, ny);
        if State <> gsPlaying then Exit;
      end;
end;

procedure TfrmMain.ToggleFlag(x, y: Integer); //Установка флажка
begin
  if not Field[x, y].open then
    if Field[x,y].flag then begin
      Field[x,y].flag := False;
      Inc(MineRest);
    end
    else begin
      Field[x,y].flag := True;
      Dec(MineRest);
    end;
    pbRest.Invalidate;
end;

procedure TfrmMain.DrawEmpty(cell: TRect; exploded: Boolean);   //пустая ячейка
begin
  if exploded then
    pbField.Canvas.Brush.Color:=clRed
  else
    pbField.Canvas.Brush.Color:=CellFaceColor;
  pbField.Canvas.FillRect(cell);

  if not exploded then
  begin
    pbField.Canvas.Pen.Style := psSolid;
    pbField.Canvas.Pen.Width := 1;
    pbField.Canvas.Pen.Color := CellShadowColor;

    pbField.Canvas.MoveTo(cell.Left, cell.Bottom - 1);
    pbField.Canvas.LineTo(cell.Right - 1, cell.Bottom - 1);
    pbField.Canvas.MoveTo(cell.Right - 1, cell.Top);
    pbField.Canvas.LineTo(cell.Right - 1, cell.Bottom - 1);
  end;
end;

procedure TfrmMain.DrawNumber(cell: TRect; num: Integer);      //ячейка с цифрой
var
  ts: TTextStyle;
begin
  DrawEmpty(cell);

  pbField.Canvas.Font.Color:=NumberColors[Num];//цвет цифры
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
  DrawClosed(cell);
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

procedure TfrmMain.DrawWrongFlag(cell: TRect);
begin
  DrawMine(cell);
  pbField.Canvas.Pen.Style := psSolid;
  pbField.Canvas.Pen.Color := clRed;
  pbField.Canvas.Pen.Width := 2;
  pbField.Canvas.MoveTo(cell.Left + 6, cell.Top + 6);
  pbField.Canvas.LineTo(cell.Right - 7, cell.Bottom - 7);
  pbField.Canvas.MoveTo(cell.Right - 7, cell.Top + 6);
  pbField.Canvas.LineTo(cell.Left + 6, cell.Bottom - 7);
end;

procedure TfrmMain.DrawClosed(cell: TRect);   //Закрытая ячейка
var
  p1, p2, p3, p4: TPoint;
  p5, p6, p7, p8: TPoint;
begin
  p1:=cell.TopLeft;
  p3 := Point(cell.Right - 1, cell.Bottom - 1);
  p2 := Point(p3.x, p1.y);
  p4 := Point(p1.x, p3.y);

  p5 := Point(p1.x + BevelWidth, p1.y + BevelWidth);
  p6 := Point(p2.x - BevelWidth, p2.y + BevelWidth);
  p7 := Point(p3.x - BevelWidth, p3.y - BevelWidth);
  p8 := Point(p4.x + BevelWidth, p4.y - BevelWidth);

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
  State := gsReady;
  lbSmile.Caption := Smiles[State];
  OpenedCount := 0;
  MineRest := MineCount;
  timer := 0;
  pbTimer.Invalidate;
  pbRest.Invalidate;
  for y:=0 to Rows - 1 do
    for x:= 0 to Cols - 1 do
      Field[x, y] := DefaultCell;
  pbField.Invalidate;
end;

procedure TfrmMain.EndGame(Won: Boolean);
var
  x, y: Integer;
begin
  if Won then begin
    State := gsWon;
    MineRest := 0;
    for x := 0 to Cols - 1 do
      for y := 0 to Rows - 1 do
        if Field[x, y].value = MineCell then
        begin
          Field[x, y].flag := True;    // авто-флаги на все мины
          Field[x, y].open := False;
        end;
  end
  else begin
    State := gsLost;
    for x:= 0 to Cols - 1 do
      for y := 0 to Rows - 1 do
        begin
          if Field[x, y].flag then
          begin
            if Field[x, y].value = MineCell then
              Field[x, y].open := False              // верный флаг — остаётся флагом
            else
            begin
              Field[x, y].value := WrongFlagCell;    // неверный — мина с крестом
              Field[x, y].flag := False;
              Field[x, y].open := True;
            end;
          end
          else
            Field[x, y].open := True;
        end;
  end;
  pbField.Invalidate;
  pbRest.Invalidate;
  lbSmile.Caption := Smiles[State];
end;

function FormatCounter(Value: Integer): string;
var
  n: Integer;
begin
  n := EnsureRange(Value, -99, 999);          // Math
  Result := IntToStr(Abs(n));
  while Length(Result) < 3 - Ord(n < 0) do
    Result := '0' + Result;
  if n < 0 then Result := '-' + Result;
end;

end.
