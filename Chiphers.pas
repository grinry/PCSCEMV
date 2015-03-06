unit Chiphers;

interface
uses
  Windows, Messages, SysUtils, Variants, Classes, StrUtils, defs,
  LbCipher,
  LbClass,
  LbRSA,
  LbBigInt,
  LbUtils;

type
  TRSAPublicKey = packed record
    Exponent,
    Modulus: AnsiString;

    function Size: integer;
    procedure Clear;
  end;

  TChipher = class
  public
    class function RSADecode(data: AnsiString; PublicKey: TRSAPublicKey): AnsiString;
    class function RSAEncode(data, PrivateKey: AnsiString): AnsiString;

    // DES_MAC_EMV | Retail MAC algorithm | ISO 9797-1 Algorithm 3
    class function DesMACEmv(data, Key: AnsiString): AnsiString;

    class function SHA1Hash(data: AnsiString): AnsiString;
  end;

implementation

{ TChipher }

// http://en.wikipedia.org/wiki/ISO/IEC_9797-1#MAC_algorithm_3
class function TChipher.DesMACEmv(data, Key: AnsiString): AnsiString;
var
  i,
  indx       : Longint;
  Block      : TDESBlock;
  PrevBlock  : TDESBlock;
  Context    : TTripleDESContext;
  DKey       : TKey128;
  BlockCount : LongInt;
  PadCount   : Byte;
  OddCount   : Byte;
begin
  Result := '';

  if Length(Key) <> SizeOf(DKey) then exit;

  Move(Key[1], DKey[0], SizeOf(DKey));
  InitEncryptTripleDES(DKey, Context, true);

  {get the number of blocks in the file}
  BlockCount := (length(data) div SizeOf(Block));
  OddCount := length(data) mod SizeOf(Block);

  { initialization vector }
  FillChar(PrevBlock, SizeOf(PrevBlock), #0);

  { get number of bytes to pad at the end }
  if (OddCount > 0) then
  begin
    PadCount := SizeOf(Block) - OddCount;
    Inc(BlockCount);
  end
  else
  begin
    PadCount := 0;
    OddCount := 8;
  end;

  indx := 1;
  {process all except the last block}
  for I := 1 to BlockCount - 1 do
  begin
    Move(data[indx], Block[0], SizeOf(Block));
    indx := indx + SizeOf(Block);

    EncryptDESCBC(Context[0], PrevBlock, Block);

    PrevBlock := Block;
  end;

  { process the last block }
  FillChar(Block, SizeOf(Block), #0);
  Move(data[indx], Block[0], OddCount);

  { pad the remaining bytes in the block }
{  if (OddCount > 0) then
    for i := OddCount to SizeOf(Block) - 1 do
      Block[i] := PadCount; // PADDING!!!!!!             }

  {encrypt and save full block}
  EncryptTripleDESCBC(Context, PrevBlock, Block);

  SetLength(Result, SizeOf(Block));
  Move(Block[0], Result[1], SizeOf(Block));
end;

class function TChipher.RSADecode(data: AnsiString; PublicKey: TRSAPublicKey): AnsiString;
var
  dwSize, dwLen : DWORD;
  Exponent, Modulus, BData,
  tmp1, tmp2 : TLbBigInt;
begin
  Result := '';

  try
    tmp1 := TLbBigInt.Create(PublicKey.Size);
    tmp2 := TLbBigInt.Create(PublicKey.Size);

    Exponent := TLbBigInt.Create(PublicKey.Size);
    Modulus := TLbBigInt.Create(PublicKey.Size);
    BData := TLbBigInt.Create(PublicKey.Size);

    Exponent.CopyBuffer(PublicKey.Exponent[1], length(PublicKey.Exponent));
    Exponent.ReverseBytes;
    Modulus.CopyBuffer(PublicKey.Modulus[1], PublicKey.Size);
    Modulus.ReverseBytes;
    BData.CopyBuffer(data[1], length(data));
    BData.ReverseBytes;

    try
      tmp1.Copy(BData);
      dwSize := tmp1.Size;
      BData.Clear;
      repeat
        dwLen := Min(dwSize, Modulus.Size);
        tmp2.CopyLen(tmp1, dwLen);
        tmp2.PowerAndMod(Exponent, Modulus);

        BData.Append(tmp2);
        tmp1.Shr_(dwLen * 8);
        dwSize := dwSize - dwLen;
      until (dwSize <= 0);

      Result := AnsiString(StringOfChar(#0, BData.Size));
      BData.ReverseBytes;
      BData.ToBuffer(Result[1], BData.Size);
    finally
      tmp1.Free;
      tmp2.Free;

      Exponent.Free;
      Modulus.Free;
      BData.Free;
    end;
  except
    Result := '';
  end;
end;

class function TChipher.RSAEncode(data, PrivateKey: AnsiString): AnsiString;
var
  RSA: TLbRSA;
begin             //  TODO!!!!!  NOT WORKS!!!!
  RSA := TLbRSA.Create(nil);
  try
    RSA.PrivateKey.ExponentAsString := '03';
    RSA.PrivateKey.ModulusAsString := Bin2HexExt(PrivateKey, false, true);

    Result := RSA.EncryptStringA(data);
  finally
    FreeAndNil(RSA);
  end;
end;

class function TChipher.SHA1Hash(data: AnsiString): AnsiString;
var
  SHA1: TLbSHA1;
  Digest: TSHA1Digest;
begin
  Result := '';

  SHA1 := TLbSHA1.Create(nil);
  SHA1.HashStringA(data);
  SHA1.GetDigest(Digest);
  SHA1.Destroy;
  SetLength(Result, 20);
  Move(Digest, Result[1], 20);
end;

{ TRSAPublicKey }

procedure TRSAPublicKey.Clear;
begin
  Exponent := '';
  Modulus := '';
end;

function TRSAPublicKey.Size: integer;
begin
  Result := length(Modulus);
end;

end.
