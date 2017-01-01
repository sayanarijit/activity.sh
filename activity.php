<?php

$basic_reports = glob("basic_report/*");
$advance_reports = glob("advance_report/*");

function read_lines($path)
{
  $file = fopen($path, "r");
  $members = array();
  while (!feof($file)) {
     $members[] = fgets($file);
  }
  fclose($file);
  unset($members[(count($members)-1)]);
  return $members;
}

function read_file($path)
{
  $myfile = fopen($path, "r");
  return fread($myfile,filesize($path));
  fclose($myfile);
}

foreach ($basic_reports as $key => $value) {
  echo "<h3>".ucfirst(str_replace('_',' ',basename($value)))."</h3>";
  echo "<table>";
  foreach(glob($value."/*") as $k => $v){
    echo "<tr><td><a href='".$v."' target='__blank'>".ucfirst(str_replace('_',' ',basename($v)))."</a></td><td>".count(read_lines($v))."</td></tr>";
  }
  echo "</table>";
}

foreach ($advance_reports as $key => $value) {
  echo "<h3>".ucfirst(str_replace('_',' ',basename($value)))."</h3>";
  foreach(glob($value."/*") as $k => $v){
    echo "<p><a href='".$v."/output' target='__blank'>".read_file($v."/name")." output</a></p>";
    echo "<p><a href='".$v."/error' target='__blank'>".read_file($v."/name")." error</a></p>";
  }
  echo "</table>";
}
?>

