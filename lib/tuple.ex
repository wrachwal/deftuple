defmodule TUPLE do
  alias __MODULE__, as: Tuple #NOTE to minimize differencies with my deftuple elixir branch
  #NOTE: where original Tuple module was needed, explicit :"Elixir.Tuple" was used instead.

  @moduledoc """
  Documentation for TUPLE.

  The code that forms this module has been extracted from
  lib/elixir/lib/tuple.ex (i.e. Tuple module) on
  [deftuple](https://github.com/wrachwal/elixir/commits/deftuple) branch,
  and module name renamed to TUPLE.

  ## Record-like API

  This module provides `deftuple/2` and `deftuplep/2` macros similar to
  `Record.defrecord/3` and `Record.defrecordp/3` macros. The only
  difference is that `deftuple/2` and `deftuplep/2` do not introduce
  a tag (atom) as the first element in a resulting tuple data.

  The advantage of having alternate API (featured with named tuple
  elements) when comparing to literal syntax of tuples becomes apparent
  when a tuple has more elements and/or its arity or structure changes
  over time in a complex code.

  Defining such "tag-less records" may seem odd, but it has at least one
  notable use case: in ETS table to store tuples of different shapes
  where the key typically consists of a fixed tag (to identify shape)
  and variable part(s) (to differentiate instances). In such heterogenic
  ETS tables there's also a place for use of records when singular
  instances are appropriate (e.g. to hold "global" counters).
  """

  @doc """
  Defines a set of macros to create, access, and pattern match on
  a tuple.

  The name of the generated macros will be `name` (which has to be an
  atom). `kv` is a keyword list of `name: default_value` fields for the
  new tuple.

  The following macros are generated:

    * `name/0` to create a new tuple with default values for all fields
    * `name/1` to create a new tuple with the given fields and values,
      to get the zero-based index of the given field in a tuple or to
      convert the given tuple to a keyword list
    * `name/2` to update an existing tuple with the given fields and values
      or to access a given field in a given tuple

  All these macros are public macros (as defined by `defmacro`).

  See the "Examples" section for examples on how to use these macros.

  ## Examples

      defmodule Space do
        require Tuple
        Tuple.deftuple :point, [x: 0, y: 0, z: 0]
      end

  In the example above, a set of macros named `point` but with different
  arities will be defined to manipulate the underlying tuple.

      # Import the module to make the point macros locally available
      import Space

      # To create tuples
      tuple = point()     #=> {0, 0, 0}
      tuple = point(x: 7) #=> {7, 0, 0}

      # To get a field from the tuple
      point(tuple, :x) #=> 7

      # To update the tuple
      point(tuple, y: 9) #=> {7, 9, 0}

      # To get the zero-based index of the field in tuple
      point(:x) #=> 0

      # Convert a tuple to a keyword list
      point(tuple) #=> [x: 7, y: 0, z: 0]

  The generated macros can also be used in order to pattern match on tuples and
  to bind variables during the match:

      point() = tuple #=> {7, 0, 0}

      point(x: x) = tuple
      x #=> 7
  """
  defmacro deftuple(name, kv) do
    quote bind_quoted: [name: name, kv: kv] do
      fields = Tuple.__fields__(:deftuple, kv)

      defmacro(unquote(name)(args \\ [])) do
        Tuple.__access__(unquote(name), unquote(fields), args, __CALLER__)
      end

      defmacro(unquote(name)(tuple, args)) do
        Tuple.__access__(unquote(name), unquote(fields), tuple, args, __CALLER__)
      end
    end
  end

  @doc """
  Same as `deftuple/2` but generates private macros.
  """
  defmacro deftuplep(name, kv) do
    quote bind_quoted: [name: name, kv: kv] do
      fields = Tuple.__fields__(:deftuplep, kv)

      defmacrop(unquote(name)(args \\ [])) do
        Tuple.__access__(unquote(name), unquote(fields), args, __CALLER__)
      end

      defmacrop(unquote(name)(tuple, args)) do
        Tuple.__access__(unquote(name), unquote(fields), tuple, args, __CALLER__)
      end
    end
  end

  # Normalizes of tuple fields to have default values.
  @doc false
  def __fields__(type, fields) do
    :lists.map(fn
      {key, val} when is_atom(key) ->
        try do
          Macro.escape(val)
        rescue
          e in [ArgumentError] ->
            raise ArgumentError, "invalid value for tuple field #{key}, " <> Exception.message(e)
        else
          val -> {key, val}
        end
      key when is_atom(key) ->
        {key, nil}
      other ->
        raise ArgumentError, "#{type} fields must be atoms, got: #{inspect other}"
    end, fields)
  end

  # Callback invoked from tuple/0 and tuple/1 macros.
  @doc false
  def __access__(atom, fields, args, caller) do
    cond do
      is_atom(args) ->
        index(atom, fields, args)
      Keyword.keyword?(args) ->
        create(atom, fields, args, caller)
      true ->
        case Macro.expand(args, caller) do
          {:{}, _, list} when length(list) == length(fields) ->
            tuple = List.to_tuple(list)
            Tuple.__keyword__(atom, fields, tuple)
          {_, _} = pair when length(fields) == 2 ->
            Tuple.__keyword__(atom, fields, pair)
          _ ->
            quote do: Tuple.__keyword__(unquote(atom), unquote(fields), unquote(args))
        end
    end
  end

  # Callback invoked from the tuple/2 macro.
  @doc false
  def __access__(atom, fields, tuple, args, caller) do
    cond do
      is_atom(args) ->
        get(atom, fields, tuple, args)
      Keyword.keyword?(args) ->
        update(atom, fields, tuple, args, caller)
      true ->
        msg = "expected arguments to be a compile time atom or keywords, got: #{Macro.to_string args}"
        raise ArgumentError, msg
    end
  end

  # Gets the index of field.
  defp index(atom, fields, field) do
    if index = find_index(fields, field, 0) do
      index - 1 # Convert to Elixir index
    else
      raise ArgumentError, "tuple #{inspect atom} does not have the key: #{inspect field}"
    end
  end

  # Creates a new tuple with the given default fields and keyword values.
  defp create(atom, fields, keyword, caller) do
    in_match = Macro.Env.in_match?(caller)
    keyword = apply_underscore(fields, keyword)

    {match, remaining} =
      Enum.map_reduce(fields, keyword, fn({field, default}, each_keyword) ->
        new_fields =
          case Keyword.fetch(each_keyword, field) do
            {:ok, value} -> value
            :error when in_match -> {:_, [], nil}
            :error -> Macro.escape(default)
          end

        {new_fields, Keyword.delete(each_keyword, field)}
      end)

    case remaining do
      [] ->
        {:{}, [], match}
      _  ->
        keys = for {key, _} <- remaining, do: key
        raise ArgumentError, "tuple #{inspect atom} does not have the key: #{inspect hd(keys)}"
    end
  end

  # Updates a tuple given by var with the given keyword.
  defp update(atom, fields, var, keyword, caller) do
    if Macro.Env.in_match?(caller) do
      raise ArgumentError, "cannot invoke update style macro inside match"
    end

    keyword = apply_underscore(fields, keyword)

    Enum.reduce keyword, var, fn({key, value}, acc) ->
      index = find_index(fields, key, 0)
      if index do
        quote do
          :erlang.setelement(unquote(index), unquote(acc), unquote(value))
        end
      else
        raise ArgumentError, "tuple #{inspect atom} does not have the key: #{inspect key}"
      end
    end
  end

  # Gets a tuple key from the given var.
  defp get(atom, fields, var, key) do
    index = find_index(fields, key, 0)
    if index do
      quote do
        :erlang.element(unquote(index), unquote(var))
      end
    else
      raise ArgumentError, "tuple #{inspect atom} does not have the key: #{inspect key}"
    end
  end

  defp find_index([{k, _} | _], k, i), do: i + 1
  defp find_index([{_, _} | t], k, i), do: find_index(t, k, i + 1)
  defp find_index([], _k, _i), do: nil

  # Returns a keyword list of the tuple
  @doc false
  def __keyword__(atom, fields, tuple) do
    if is_tuple(tuple) do
      values = :"Elixir.Tuple".to_list(tuple)
      case join_keyword(fields, values, []) do
        kv when is_list(kv) ->
          kv
        expected_size ->
          msg = "expected argument to be a #{inspect atom} tuple of size #{expected_size}, got: #{inspect tuple}"
          raise ArgumentError, msg
      end
    else
      msg = "expected argument to be a literal atom, literal keyword or a #{inspect atom} tuple, got runtime: #{inspect tuple}"
      raise ArgumentError, msg
    end
  end

  # Returns a keyword list, or expected size on size mismatch
  defp join_keyword([{field, _default} | fields], [value | values], acc),
    do: join_keyword(fields, values, [{field, value} | acc])
  defp join_keyword([], [], acc),
    do: :lists.reverse(acc)
  defp join_keyword(rest_fields, _rest_values, acc),
    do: length(acc) + length(rest_fields) # expected size

  defp apply_underscore(fields, keyword) do
    case Keyword.fetch(keyword, :_) do
      {:ok, default} ->
        fields
        |> Enum.map(fn {k, _} -> {k, default} end)
        |> Keyword.merge(keyword)
        |> Keyword.delete(:_)
      :error ->
        keyword
    end
  end
end
