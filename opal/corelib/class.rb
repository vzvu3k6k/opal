require 'corelib/module'

class ::Class
  def self.new(superclass = Object, &block)
    %x{
      if (!superclass.$$is_class) {
        throw Opal.TypeError.$new("superclass must be a Class");
      }

      var klass = Opal.allocate_class(nil, superclass);
      superclass.$inherited(klass);
      #{`klass`.class_eval(&block) if block_given?}
      return klass;
    }
  end

  def allocate
    %x{
      var obj = new self.$$constructor();
      obj.$$id = Opal.uid();
      return obj;
    }
  end

  def descendants
    subclasses + subclasses.map(&:descendants).flatten
  end

  def inherited(cls)
  end

  def initialize_dup(original)
    initialize_copy(original)
    %x{
      self.$$name = null;
      self.$$full_name = null;
    }
  end

  def new(*args, &block)
    %x{
      var object = #{allocate};
      Opal.send(object, object.$initialize, args, block);
      return object;
    }
  end

  def subclasses
    %x{
      if (typeof WeakRef !== 'undefined') {
        var i, subclass, out = [];
        for (i = 0; i < self.$$subclasses.length; i++) {
          subclass = self.$$subclasses[i].deref();
          if (subclass !== undefined) {
            out.push(subclass);
          }
        }
        return out;
      }
      else {
        return self.$$subclasses;
      }
    }
  end

  def superclass
    `self.$$super || nil`
  end

  def to_s
    %x{
      var singleton_of = self.$$singleton_of;

      if (singleton_of && singleton_of.$$is_a_module) {
        return #{"#<Class:#{`singleton_of`.name}>"};
      }
      else if (singleton_of) {
        // a singleton class created from an object
        return #{"#<Class:#<#{`singleton_of.$$class`.name}:0x#{`Opal.id(singleton_of)`.to_s(16)}>>"};
      }

      return #{super()};
    }
  end

  def attached_object
    %x{
      if (self.$$singleton_of != null) {
        return self.$$singleton_of;
      }
      else {
        #{::Kernel.raise ::TypeError, "`#{self}' is not a singleton class"}
      }
    }
  end

  alias inspect to_s
end
