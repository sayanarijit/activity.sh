<?php
$activity_name = basename(dirname(__FILE__));
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
?>
<!DOCTYPE html>
<html>
<head>
  <title>Activity report for - <?php echo $activity_name?></title>
  <style>
    body {margin:0;
          font-family: Arial,"Helvetica Neue",Helvetica,sans-serif;
          font-size: 14px;}
    h1   {color: #FFF; background: rgba(12,13,14,0.86); margin:0; padding: 10px}
    a    {text-decoration: none;padding: 5px; display: block; width: 100%}
    div {padding:1%}
    a:hover    {background-color: #E1E1E1}
  </style>
</head>
<body>

<?php
$i=0;
$j=0;
$fileID = array();
$dirID = array();
# ---------------------------- display page ------------------------------------
# Heading
echo "<h1>Activity report for - ".$activity_name."</h1>";
echo "<div style='width:28%; float:left'>";

# Left panel
foreach ($basic_reports as $key => $value) {
  echo "<h3>".ucfirst(str_replace('_',' ',basename($value)))."</h3>";
  echo "<table>";
  foreach(glob($value."/*") as $k => $v){
    $fileID[$i] = $v;
    echo "<tr><td><a href='?file=".$i."'>".ucfirst(str_replace('_',' ',basename($v)))."</a></td><td>: ".count(read_lines($v))."</td></tr>";
    $i++;
  }
  echo "</table>";
}

foreach ($advance_reports as $key => $value) {
  echo "<h3>".ucfirst(str_replace('_',' ',basename($value)))."</h3>";
  foreach(glob($value."/*") as $k => $v){
    $dirID[$j.'-output'] = $v."/output";
    $dirID[$j.'-error'] = $v."/error";
    echo "<a href='?dir=".$j."-output'>".read_file($v."/name")." : output</a>";
    echo "<a href='?dir=".$j."-error'>".read_file($v."/name")." : error</a>";
    $j++;
  }
  echo "</table>";
}
echo "<hr/><h3>All Activity reports</h3>";
$files = glob("../*");
foreach ($files as $f){
  echo "<a href='".$f."'>".basename($f)."</a>";
}
echo "</div>";

# Middle panel
echo "<div style='width:18%; float:left'>";
if (isset($_GET['dir'])&&(!empty($_GET['dir']))&&(is_dir($dirID[$_GET['dir']]))){
  echo "<h3>".read_file($dirID[$_GET['dir']]."/../name")." : ".str_replace('_',' ',basename(dirname($dirID[$_GET['dir']]."/.")))."</h3>";
  echo "<a href='?dir=".$_GET['dir']."&file=*'>Show all</a><hr/>";
  $files = glob($dirID[$_GET['dir']]."/*");
  foreach ($files as $f){
    $fileID[$i] = $f;
    echo "<a href='?dir=".$_GET['dir']."&file=".$i."'>".basename($f)."</a>";
    $i++;
  }
}
echo "</div>";

# Right panel
echo "<div style='width:48%; float:left'>";
if (isset($_GET['file'])){
  if (isset($_GET['dir'])&&(is_dir($_GET['dir']))&&($_GET['file'] == "*")){
    $files = glob($_GET['dir']."/*");
    foreach ($files as $f){
      echo "<h3>".str_replace('_',' ',basename(dirname($f."/.")))."</h3>";
      echo "<div style='background-color: #E1E1E1'>";
      $lines = read_lines($f);
      foreach ($lines as $l){
        echo $l."<br/>";
      }
      echo "</div>";
    }
  }elseif(is_file($fileID[$_GET['file']])){
    echo "<h3>".str_replace('_',' ',basename($fileID[$_GET['file']]))."</h3>";
    echo "<div style='background-color: #E1E1E1'>";
    $lines = read_lines($fileID[$_GET['file']]);
    foreach ($lines as $l){
      echo $l."<br/>";
    }
    echo "</div>";
  }
}
echo "</div>";
?>
</body></html>
