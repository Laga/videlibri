#!/bin/bash



libData=$1
publishId=$2
tmp=/tmp/tmpvl$publishId

source ../../../manageUtils.sh
sfProject videlibri
VIDELIBRIBASE=$HGROOT/programs/internet/VideLibri



eval $(xidel --output-format bash $libData -e 'name:=//longName/@value, templateId:=//template/@value')
libDataNew=$(basename $libData | sed -e 's/[.]xml/New.xml/' )
libDataIdNew=$( sed -e 's/[.]xml//' <<<"$libDataNew")
if [[ "$3" = "--override" ]]; then templateIdNew=${templateId}
else templateIdNew=${templateId}New
fi
templatePath=$(grep -oE '.*/' <<<$libData)templates


rm -rf $tmp
mkdir $tmp
mkdir $tmp/newlibs


cat > $tmp/$publishId.html <<EOF 
<html>
<head>
<link rel="videlibri.description" href="newlibs/$libDataNew"/>
<link rel="videlibri.template" href="$templateIdNew/template"/>
</head>
<body>
Neues Template f&uuml;r  die "$name"
</body>
</html>
EOF

#cat $tmp/$publishId.html

cp -Lr $templatePath/$templateId $tmp/$templateIdNew
cp $libData $tmp/newlibs/$libDataNew

#sed -e '' -i $tmp/newlibs/$libDataNew
xmlstarlet ed -L -u //longName/@value -v "$name (Neu)" $tmp/newlibs/$libDataNew
xmlstarlet ed -L -u //template/@value -v "$templateIdNew" $tmp/newlibs/$libDataNew
xmlstarlet ed -L -s /library -t elem -n "id" -v "" $tmp/newlibs/$libDataNew
xmlstarlet ed -L -s /library/id -t attr -n "value" -v "$libDataIdNew" $tmp/newlibs/$libDataNew
xmlstarlet ed -L -u //id/@value -v "$libDataIdNew" $tmp/newlibs/$libDataNew
#xmlstarlet ed -L -u //id -v "$libDataIdNew" $tmp/newlibs/$libDataNew
if [[ "$3" = "--override" ]]; then
INTVERSION=`grep 'versionNumber *: *integer' $VIDELIBRIBASE/applicationconfig.pas | grep -oE "[0-9]+" | head -1 `;
xmlstarlet ed -L --insert "/actions" --type attr -n "max-version" -v "$INTVERSION" $tmp/$templateIdNew/template
xmlstarlet ed -L --insert "/actions" --type attr -n "version-mismatch" -v "skip" $tmp/$templateIdNew/template
fi

cd $tmp
ls
webUpload * /test/
webUpload newlibs/* /test/newlibs/
webUpload $templateIdNew/* /test/$templateIdNew/