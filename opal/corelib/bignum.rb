class Bignum < Integer
  Opal.bridge(`BigInt`, self)
  `Opal.defineProperty(self.$$prototype, '$$is_bignum', true)`

  def to_s
    `self.toString()`
  end

  for i in %i[+ - * / fdiv % & | ^]
    define_method i do |other|
      super(other.to_bn)
    end
  end

  def **(other)
    `self ** #{other.to_bn}`
  end

  alias to_bn itself

  def to_f
    `Number(self)`
  end

  def to_i
    `Math.floor(Number(self))`
  end

  alias to_int to_i

  alias inspect to_s
end

class Numeric
  def to_bn
    `BigInt(self)`
  end
end

class String
  def to_bn
    `BigInt(self)`
  end
end
