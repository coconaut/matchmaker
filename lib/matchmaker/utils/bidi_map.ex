defmodule Matchmaker.Utils.BidiMap do

  # TODO: spec out, consider wrapping w/ bowfish in a utils pkg 
  # if you eventually have enough useful things

  # expand this as needed
  
  def new() do
    {Map.new(), Map.new()}
  end

  def get_fwd({bi, _di}, key) do
    Map.get(bi, key)
  end

  def fetch_fwd({bi, _di}, key) do
    Map.fetch(bi, key)
  end

  def get_rev({_bi, di}, key) do
    Map.get(di, key)
  end

  def fetch_rev({_bi, di}, key) do
    Map.fetch(di, key)
  end

  def put({bi, di}, key, val) do
    {Map.put(bi, key, val), Map.put(di, val, key)}
  end

  def delete_fwd({bi, di} = bidi, key) do
    {val, nu_bi} = Map.pop(bi, key)
    {nu_bi, Map.delete(di, val)}
  end

  def delete_rev({bi, di} = bidi, key) do
    {val, nu_di} = Map.pop(di, key)
    {Map.delete(bi, val), nu_di}
  end
end